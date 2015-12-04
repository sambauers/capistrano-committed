namespace :committed do
  task :check_prerequisites do
    # Checks all the settings to make sure they are OK - mostly just checks type
    {:committed_user => 'user', :committed_repo => 'repository'}.each do |variable, name|
      raise TypeError,
            I18n.t('capistrano.committed.error.prerequisites.nil', variable: variable, name: name) if fetch(variable).nil?
      raise ArgumentError,
            I18n.t('capistrano.committed.error.prerequisites.empty', variable: variable, name: name) if fetch(variable).empty?
    end

    raise TypeError,
          I18n.t('capistrano.committed.error.prerequisites.string', variable: 'committed_revision_line') unless fetch(:committed_revision_line).is_a?(String)
    raise TypeError,
          I18n.t('capistrano.committed.error.prerequisites.hash', variable: 'committed_github_config') unless fetch(:committed_github_config).is_a?(Hash)
    raise TypeError,
          I18n.t('capistrano.committed.error.prerequisites.integer', variable: 'committed_revision_limit') unless fetch(:committed_revision_limit).is_a?(Integer)
    raise TypeError,
          I18n.t('capistrano.committed.error.prerequisites.integer', variable: 'committed_commit_buffer') unless fetch(:committed_commit_buffer).is_a?(Integer)
    raise TypeError,
          I18n.t('capistrano.committed.error.prerequisites.string_or_nil', variable: 'committed_output_path') unless fetch(:committed_output_path).is_a?(String) || fetch(:committed_output_path).nil?
    raise TypeError,
          I18n.t('capistrano.committed.error.prerequisites.string_or_regexp_or_nil', variable: 'committed_issue_match') unless fetch(:committed_issue_match).is_a?(String) || fetch(:committed_issue_match).is_a?(Regexp) || fetch(:committed_issue_match).nil?
    raise TypeError,
          I18n.t('capistrano.committed.error.prerequisites.string_or_nil', variable: 'committed_issue_url') unless fetch(:committed_issue_url).is_a?(String) || fetch(:committed_issue_url).nil?
  end

  desc 'Generetes a report of commit and pull request status on the current stage'
  task :generate do
    invoke 'committed:check_prerequisites'

    # Only do this on the primary web server
    on primary :web do
      # Get the Capistrano revision log
      lines = capture(:cat, revision_log).split("\n").reverse

      # Build the regex to search for revision data in the log, by default this
      # is the localised string from Capistrano
      search = fetch(:committed_revision_line)
      search = Regexp.escape(search)
      search = search.gsub('%\{', '(?<').gsub('\}', '>.+)')
      search = Regexp.new(search)

      # Build the revisions hash
      revisions = {}
      lines.each do |line|
        matches = search.match(line)
        next unless matches[:branch].to_s == fetch(:branch).to_s
        revisions[matches[:sha]] = {
          :branch => matches[:branch],
          :sha => matches[:sha],
          :release => matches[:release],
          :user => matches[:user],
          :entries => {}
        }
        # Only store a certain number of revisions
        break if revisions.count == fetch(:committed_revision_limit)
      end

      # No revisions, no log
      if revisions.empty?
        info I18n.t('capistrano.committed.error.runtime.revisions_empty',
                    branch: fetch(:branch).to_s,
                    stage: fetch(:stage).to_s)
        return
      end

      # Sort revisions by release date
      revisions = revisions.sort_by{|sha, matches| matches[:release]}.to_h
      # Add the "next" revision
      revisions.merge!({
        :next => {
          :entries => {}
        }
      })
      # Reverse the order of revisions in the hash (most recent first)
      revisions = revisions.to_a.reverse.to_h
      revisions.merge!({
        :previous => {
          :entries => {}
        }
      })

      # Initialize the GitHub API client
      github = ::Capistrano::Committed::GithubApi.new(fetch(:committed_github_config))

      # Get the actual date of the commit referenced to by the revision
      earliest_date = nil
      revisions.each do |sha, revision|
        next if sha == :next || sha == :previous
        commit = github.get_commit(fetch(:committed_user), fetch(:committed_repo), sha)
        unless commit.nil?
          earliest_date = commit[:commit][:committer][:date]
          revisions[sha][:date] = earliest_date
        end
      end

      # No commit data on revisions, no log
      if earliest_date.nil?
        info I18n.t('capistrano.committed.error.runtime.revision_commit_missing',
                    branch: fetch(:branch).to_s,
                    stage: fetch(:stage).to_s)
        return
      end

      # Go back an extra N day
      earliest_date = (Time.parse(earliest_date) - (fetch(:committed_commit_buffer) * 24 * 60 * 60)).iso8601
      revisions[:previous][:date] = earliest_date

      # Get all the commits on this branch
      commits = github.get_commits_since(fetch(:committed_user),
                                         fetch(:committed_repo),
                                         earliest_date,
                                         fetch(:branch).to_s)

      # No commits, no log
      if commits.empty?
        info I18n.t('capistrano.committed.error.runtime.commits_empty',
                    branch: fetch(:branch).to_s,
                    stage: fetch(:stage).to_s,
                    time: earliest_date)
        return
      end

      # Map commits to a hash keyed by sha
      commits = Hash[commits.map { |commit| [commit[:sha], commit] }]

      # Get all pull requests listed in the commits
      revision_index = 0
      commits.each do |sha, commit|
        # Match to GitHub generated commit message, or don't
        matches = /^Merge pull request \#([0-9]+)/.match(commit[:commit][:message])
        next unless matches && matches[1]

        # Get the pull request from GitHub
        pull_request = github.get_pull_request(fetch(:committed_user),
                                               fetch(:committed_repo),
                                               matches[1].to_i)

        # Get the previous revisions commit time and the merge time of the pull request
        previous_revision = revisions[revisions.keys[revision_index + 1]]
        previous_revision_date = Time.parse(previous_revision[:date])
        merged_at = Time.parse(pull_request[:info][:merged_at])

        # Unless this pull request was merged before the previous release reference was committed
        unless merged_at > previous_revision_date
          # Move to the previous revision
          revision_index += 1
        end

        # Push pull request data in to the revision entries hash
        revisions[revisions.keys[revision_index]][:entries][pull_request[:info][:merged_at]] = [{
          :type => :pull_request,
          :info => pull_request[:info],
          :commits => pull_request[:commits]
        }]

        # Delete commits which are in this pull request from the hash of commits
        commits.delete(sha)
        next if pull_request[:commits].empty?
        pull_request[:commits].each do |c|
          commits.delete(c[:sha])
        end
      end

      # Loop through remaining commits and push them into th revision entries hash
      revision_index = 0
      commits.each do |sha, commit|
        previous_revision = revisions[revisions.keys[revision_index + 1]]
        previous_revision_date = Time.parse(previous_revision[:date])
        committed_at = Time.parse(commit[:commit][:committer][:date])

        unless committed_at > previous_revision_date
          revision_index += 1
        end

        if revisions[revisions.keys[revision_index]][:entries][commit[:commit][:committer][:date]].nil?
          revisions[revisions.keys[revision_index]][:entries][commit[:commit][:committer][:date]] = []
        end
        revisions[revisions.keys[revision_index]][:entries][commit[:commit][:committer][:date]] << {
          :type => :commit,
          :info => commit
        }
      end

      # Loop through the revisions to create the output
      output = []
      revisions.each do |sha, revision|

        # Build the revision header
        output << ''
        output << '==============================================================================================='
        case sha
        when :next
          output << I18n.t('capistrano.committed.output.next_release')
        when :previous
          output << I18n.t('capistrano.committed.output.previous_release',
                           time: revision[:date])
        else
          output << I18n.t('capistrano.committed.output.current_release',
                           release_time: Time.parse(revision[:release]).iso8601,
                           sha: revision[:sha],
                           commit_time: revision[:date])
        end
        output << '==============================================================================================='
        output << ''

        # Loop through the entries in this revision
        revision[:entries].sort_by{|date, entries| date}.reverse.to_h.each do |date, entries|
          entries.each do |entry|
            case entry[:type]
            when :pull_request
              # These are pull requests that are included in this revision

              # Print out the pull request number and title
              output << sprintf(' * %s',
                                I18n.t('capistrano.committed.output.pull_request_number',
                                       number: entry[:info][:number]))
              output << sprintf('   %s', entry[:info][:title])
              output << ''

              # Print out each line of the pull request description
              lines = entry[:info][:body].chomp.split("\n")
              unless lines.empty?
                output << sprintf('   %s', lines.join("\n   "))
                output << ''
              end

              unless fetch(:committed_issue_match).nil? || fetch(:committed_issue_url).nil?
                # Get any issue numbers referred to in the commit info and print links to them
                issues = ::Capistrano::Committed.scan_for_issues(fetch(:committed_issue_match),
                                                                 entry[:info][:title] + entry[:info][:body])
                unless issues.nil?
                  output << sprintf('   %s',
                                    I18n.t('capistrano.committed.output.issue_links'))
                  issues.each do |issue|
                    url = sprintf(fetch(:committed_issue_url), issue)
                    output << sprintf('   - %s', url)
                  end
                  output << ''
                end
              end

              # Merger details
              output << sprintf('   %s',
                                I18n.t('capistrano.committed.output.merged_on',
                                       time: entry[:info][:merged_at]))
              output << sprintf('   %s',
                                I18n.t('capistrano.committed.output.merged_by',
                                       login: entry[:info][:merged_by][:login]))
              output << ''

              # Print a link to the pull request on GitHub
              output << sprintf('   %s', entry[:info][:html_url])
              output << ''

              # Loop through the commits in this pull request
              unless entry[:commits].nil?
                entry[:commits].each do |commit|
                  output << '    -------------------------------------------------------------------------------------------'
                  output << '   |'

                  # Print the commit ref
                  output << sprintf('   | * %s',
                                    I18n.t('capistrano.committed.output.commit_sha',
                                           sha: commit[:sha]))
                  output << '   |'

                  # Print the commit message
                  lines = commit[:commit][:message].chomp.split("\n")
                  unless lines.empty?
                    output << sprintf('   |   > %s', lines.join("\n   |   > "))
                    output << '   |'

                    unless fetch(:committed_issue_match).nil? || fetch(:committed_issue_url).nil?
                      # Get any issue numbers referred to in the commit message and print links to them
                      issues = ::Capistrano::Committed.scan_for_issues(fetch(:committed_issue_match),
                                                                       commit[:commit][:message])
                      unless issues.nil?
                        output << sprintf('   |   %s',
                                          I18n.t('capistrano.committed.output.issue_links'))
                        issues.each do |issue|
                          url = sprintf(fetch(:committed_issue_url), issue)
                          output << sprintf('   |   - %s' , url)
                        end
                        output << '   |'
                      end
                    end
                  end

                  # Committer details
                  output << sprintf('   |   %s',
                                    I18n.t('capistrano.committed.output.committed_on',
                                           time: commit[:commit][:committer][:date]))
                  output << sprintf('   |   %s',
                                    I18n.t('capistrano.committed.output.committed_by',
                                           login: commit[:committer][:login]))
                  output << '   |'

                  # Print a link to the commit in GitHub
                  output << sprintf('   |   %s', commit[:html_url])
                  output << '   |'
                end
                output << '    -------------------------------------------------------------------------------------------'
                output << ''
              end

            when :commit
              # These are commits that are included in this revision, but are not in any pull requests

              # Print the commit ref
              output << sprintf(' * %s',
                                I18n.t('capistrano.committed.output.commit_sha',
                                       sha: entry[:info][:sha]))
              output << ''

              # Print the commit message
              lines = entry[:info][:commit][:message].chomp.split("\n")
              unless lines.empty?
                output << sprintf('   > %s', lines.join("\n   > "))
                output << ''

                unless fetch(:committed_issue_match).nil? || fetch(:committed_issue_url).nil?
                  # Get any issue numbers referred to in the commit message and print links to them
                  issues = ::Capistrano::Committed.scan_for_issues(fetch(:committed_issue_match),
                                                                   entry[:info][:commit][:message])
                  unless issues.nil?
                    output << sprintf('   %s',
                                      I18n.t('capistrano.committed.output.issue_links'))
                    issues.each do |issue|
                      url = sprintf(fetch(:committed_issue_url), issue)
                      output << sprintf('   - %s', url)
                    end
                    output << ''
                  end
                end
              end

              # Committer details
              output << sprintf('   %s',
                                I18n.t('capistrano.committed.output.committed_on',
                                       time: entry[:info][:commit][:committer][:date]))
              output << sprintf('   %s',
                                I18n.t('capistrano.committed.output.committed_by',
                                       login: entry[:info][:committer][:login]))
              output << ''

              # Print a link to the commit in GitHub
              output << sprintf('   %s', entry[:info][:html_url])
              output << ''
            end

            output << '-----------------------------------------------------------------------------------------------'
            output << ''
          end
        end

        output << ''
      end

      # Send the output to screen, or to a file on the server
      if fetch(:committed_output_path).nil?
        # Just print to STDOUT
        puts output
      else
        # Determine the output path and upload the output there
        output_path = sprintf(fetch(:committed_output_path), current_path)
        upload! StringIO.new(output.join("\n")), output_path

        # Make sure the report is world readable
        execute(:chmod, 'a+r', output_path)
      end
    end
  end
end

# Load the default settings
namespace :load do
  task :defaults do
    # See README for descriptions of each setting
    set :committed_user,            ->{ nil }
    set :committed_repo,            ->{ nil }
    set :committed_revision_line,   ->{ I18n.t('capistrano.revision_log_message') }
    set :committed_github_config,   ->{ {} }
    set :committed_revision_limit,  ->{ 10 }
    set :committed_commit_buffer,   ->{ 1 }
    set :committed_output_path,     ->{ '%s/public/committed.txt' }
    set :committed_issue_match,     ->{ '\[\s?([A-Z0-9]+\-[0-9]+)\s?\]' }
    set :committed_issue_url,       ->{ 'https://example.jira.com/browse/%s' }
  end
end
