namespace :committed do
  task :check_prerequisites do
    # Checks all the settings to make sure they are OK - mostly just checks type
    { committed_user: 'user',
      committed_repo: 'repository' }.each do |variable, name|
      fail TypeError, t('committed.error.prerequisites.nil',
                        variable: variable,
                        name: name) if
                          fetch(variable).nil?

      fail ArgumentError, t('committed.error.prerequisites.empty',
                            variable: variable,
                            name: name) if
                              fetch(variable).empty?
    end

    fail TypeError, t('committed.error.prerequisites.hash',
                      variable: 'committed_github_config') unless
                        fetch(:committed_github_config).is_a?(Hash)
  end

  task :check_report_prerequisites do
    # Checks all the settings to make sure they are OK - mostly just checks type
    fail TypeError, t('committed.error.prerequisites.string',
                      variable: 'committed_revision_line') unless
                        fetch(:committed_revision_line).is_a?(String)

    fail TypeError, t('committed.error.prerequisites.integer',
                      variable: 'committed_revision_limit') unless
                        fetch(:committed_revision_limit).is_a?(Integer)

    fail TypeError, t('committed.error.prerequisites.integer',
                      variable: 'committed_commit_buffer') unless
                        fetch(:committed_commit_buffer).is_a?(Integer)

    fail TypeError, t('committed.error.prerequisites.string_or_nil',
                      variable: 'committed_output_path') unless
                        fetch(:committed_output_path).is_a?(String) ||
                        fetch(:committed_output_path).nil?

    fail TypeError, t('committed.error.prerequisites.string_or_regexp_or_nil',
                      variable: 'committed_issue_match') unless
                        fetch(:committed_issue_match).is_a?(String) ||
                        fetch(:committed_issue_match).is_a?(Regexp) ||
                        fetch(:committed_issue_match).nil?

    fail TypeError, t('committed.error.prerequisites.string_or_nil',
                      variable: 'committed_issue_url') unless
                        fetch(:committed_issue_url).is_a?(String) ||
                        fetch(:committed_issue_url).nil?
  end

  # task :register_deployment_pending do
  #   invoke 'committed:check_prerequisites'

  #   github = ::Capistrano::Committed::GithubApi.new(fetch(:committed_github_config))
  #   deployment = github.register_deployment(fetch(:committed_user),
  #                                           fetch(:committed_repo),
  #                                           fetch(:stage).to_s,
  #                                           fetch(:branch).to_s)

  #   return if deployment.nil?

  #   github.register_status(fetch(:committed_user),
  #                          fetch(:committed_repo),
  #                          deployment[:id],
  #                          'pending')

  #   set :committed_deployment_id, deployment[:id]
  # end

  # task :register_deployment_success do
  #   invoke 'committed:check_prerequisites'

  #   id = fetch(:committed_deployment_id)
  #   return if id.nil?
  # end

  # task :register_deployment_failure do
  #   invoke 'committed:check_prerequisites'

  #   id = fetch(:committed_deployment_id)
  #   return if id.nil?
  # end

  desc 'Generetes a report of commits and pull requests on the current stage'
  task :generate do
    invoke 'committed:check_prerequisites'
    invoke 'committed:check_report_prerequisites'

    # Only do this on the primary web server
    on primary :web do
      # Get the Capistrano revision log
      lines = capture(:cat, revision_log).split("\n").reverse

      # Build the regex to search for revision data in the log, by default this
      # is the localised string from Capistrano
      search = ::Capistrano::Committed.revision_search_regex(fetch(:committed_revision_line))

      # Build the revisions hash
      revisions = ::Capistrano::Committed.get_revisions_from_lines(lines, search, fetch(:branch), fetch(:committed_revision_limit))

      # No revisions, no log
      if revisions.empty?
        info t('committed.error.runtime.revisions_empty',
               branch: fetch(:branch).to_s,
               stage: fetch(:stage).to_s)
        return
      end

      # Initialize the GitHub API client
      github = ::Capistrano::Committed::GithubApi.new(fetch(:committed_github_config))

      # Get the actual date of the commit referenced to by the revision
      earliest_date = nil
      revisions.each do |release, revision|
        next if release == :next || release == :previous
        commit = github.get_commit(fetch(:committed_user),
                                   fetch(:committed_repo),
                                   revision[:sha])
        unless commit.nil?
          earliest_date = commit[:commit][:committer][:date]
          revisions[release][:date] = earliest_date
        end
      end

      # No commit data on revisions, no log
      if earliest_date.nil?
        info t('committed.error.runtime.revision_commit_missing',
               branch: fetch(:branch).to_s,
               stage: fetch(:stage).to_s)
        return
      end

      # Go back an extra N day
      buffer = fetch(:committed_commit_buffer) * 24 * 60 * 60
      earliest_date = (Time.parse(earliest_date) - buffer).iso8601
      revisions[:previous][:date] = earliest_date

      # Get all the commits on this branch
      commits = github.get_commits_since(fetch(:committed_user),
                                         fetch(:committed_repo),
                                         earliest_date,
                                         fetch(:branch).to_s)

      # No commits, no log
      if commits.empty?
        info t('committed.error.runtime.commits_empty',
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
        message = /^Merge pull request \#([0-9]+)/
        matches = message.match(commit[:commit][:message])
        next unless matches && matches[1]

        # Get the pull request from GitHub
        pull_request = github.get_pull_request(fetch(:committed_user),
                                               fetch(:committed_repo),
                                               matches[1].to_i)

        # Get the previous revisions commit time and the merge time of the pull
        # request
        previous_revision = revisions[revisions.keys[revision_index + 1]]
        previous_revision_date = Time.parse(previous_revision[:date])
        merged_at = Time.parse(pull_request[:info][:merged_at])

        # Unless this pull request was merged before the previous release
        # reference was committed
        unless merged_at > previous_revision_date
          # Move to the previous revision
          revision_index += 1
        end

        # Push pull request data in to the revision entries hash
        key = revisions.keys[revision_index]
        revisions[key][:entries][pull_request[:info][:merged_at]] = [{
          type:     :pull_request,
          info:     pull_request[:info],
          commits:  pull_request[:commits]
        }]

        # Delete commits which are in this pull request from the hash of commits
        commits.delete(sha)
        next if pull_request[:commits].empty?
        pull_request[:commits].each do |c|
          commits.delete(c[:sha])
        end
      end

      # Loop through remaining commits and push them into the revision entries
      # hash
      revision_index = 0
      commits.each do |_sha, commit|
        previous_revision = revisions[revisions.keys[revision_index + 1]]
        previous_revision_date = Time.parse(previous_revision[:date])
        date = commit[:commit][:committer][:date]
        committed_at = Time.parse(date)

        revision_index += 1 unless committed_at > previous_revision_date

        key = revisions.keys[revision_index]
        if revisions[key][:entries][date].nil?
          revisions[key][:entries][date] = []
        end
        revisions[key][:entries][date] << {
          type: :commit,
          info: commit
        }
      end

      # Loop through the revisions to create the output
      output = []
      revisions.each do |release, revision|
        # Build the revision header
        output << ''
        output << ('=' * 94)
        case release
        when :next
          output << t('committed.output.next_release')
        when :previous
          output << t('committed.output.previous_release',
                      time: revision[:date])
        else
          output << t('committed.output.current_release',
                      release_time: Time.parse(revision[:release]).iso8601,
                      sha: revision[:sha],
                      commit_time: revision[:date])
        end
        output << ('=' * 94)
        output << ''

        # Loop through the entries in this revision
        items = Hash[revision[:entries].sort_by { |date, _entries| date }.reverse]
        items.each do |_date, entries|
          entries.each do |entry|
            case entry[:type]
            when :pull_request
              # These are pull requests that are included in this revision

              # Print out the pull request number and title
              output << format(' * %s',
                               t('committed.output.pull_request_number',
                                 number: entry[:info][:number]))
              output << format('   %s', entry[:info][:title])
              output << ''

              # Print out each line of the pull request description
              lines = entry[:info][:body].chomp.split("\n")
              unless lines.empty?
                output << format('   %s', lines.join("\n   "))
                output << ''
              end

              # Get any issue numbers referred to in the commit info and print
              # links to them
              urls = ::Capistrano::Committed.get_issue_urls(fetch(:committed_issue_match),
                                                            fetch(:committed_issue_postprocess),
                                                            fetch(:committed_issue_url),
                                                            entry[:info][:title] + entry[:info][:body])
              output += ::Capistrano::Committed.format_issue_urls(urls)

              # Merger details
              output << format('   %s',
                               t('committed.output.merged_on',
                                 time: entry[:info][:merged_at]))
              output << format('   %s',
                               t('committed.output.merged_by',
                                 login: entry[:info][:merged_by][:login]))
              output << ''

              # Print a link to the pull request on GitHub
              output << format('   %s', entry[:info][:html_url])
              output << ''

              # Loop through the commits in this pull request
              unless entry[:commits].nil?
                entry[:commits].each do |commit|
                  output << ('    ' + ('-' * 90))
                  output << '   |'

                  # Print the commit ref
                  output << format('   | * %s',
                                   t('committed.output.commit_sha',
                                     sha: commit[:sha]))
                  output << '   |'

                  # Print the commit message
                  lines = commit[:commit][:message].chomp.split("\n")
                  unless lines.empty?
                    output << format('   |   > %s', lines.join("\n   |   > "))
                    output << '   |'

                    # Get any issue numbers referred to in the commit message
                    # and print links to them
                    urls = ::Capistrano::Committed.get_issue_urls(fetch(:committed_issue_match),
                                                                  fetch(:committed_issue_postprocess),
                                                                  fetch(:committed_issue_url),
                                                                  commit[:commit][:message])
                    output += ::Capistrano::Committed.format_issue_urls(urls,
                                                                        '   |')
                  end

                  # Committer details
                  output << format('   |   %s',
                                   t('committed.output.committed_on',
                                     time: commit[:commit][:committer][:date]))
                  output << format('   |   %s',
                                   t('committed.output.committed_by',
                                     login: commit[:committer][:login]))
                  output << '   |'

                  # Print a link to the commit in GitHub
                  output << format('   |   %s', commit[:html_url])
                  output << '   |'
                end
                output << ('    ' + ('-' * 90))
                output << ''
              end

            when :commit
              # These are commits that are included in this revision, but are
              # not in any pull requests

              # Print the commit ref
              output << format(' * %s',
                               t('committed.output.commit_sha',
                                 sha: entry[:info][:sha]))
              output << ''

              # Print the commit message
              lines = entry[:info][:commit][:message].chomp.split("\n")
              unless lines.empty?
                output << format('   > %s', lines.join("\n   > "))
                output << ''

                # Get any issue numbers referred to in the commit message and
                # print links to them
                urls = ::Capistrano::Committed.get_issue_urls(fetch(:committed_issue_match),
                                                              fetch(:committed_issue_postprocess),
                                                              fetch(:committed_issue_url),
                                                              entry[:info][:commit][:message])
                output += ::Capistrano::Committed.format_issue_urls(urls)
              end

              # Committer details
              output << format('   %s',
                               t('committed.output.committed_on',
                                 time: entry[:info][:commit][:committer][:date]))
              output << format('   %s',
                               t('committed.output.committed_by',
                                 login: entry[:info][:committer][:login]))
              output << ''

              # Print a link to the commit in GitHub
              output << format('   %s', entry[:info][:html_url])
              output << ''
            end

            output << ('-' * 94)
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
        output_path = format(fetch(:committed_output_path), current_path)
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
    set :committed_user,              -> { nil }
    set :committed_repo,              -> { nil }
    set :committed_revision_line,     -> { t('revision_log_message') }
    set :committed_github_config,     -> { {} }
    set :committed_revision_limit,    -> { 10 }
    set :committed_commit_buffer,     -> { 1 }
    set :committed_output_path,       -> { '%s/public/committed.txt' }
    set :committed_issue_match,       -> { '\[\s?([a-zA-Z0-9]+\-[0-9]+)\s?\]' }
    set :committed_issue_postprocess, -> { [] }
    set :committed_issue_url,         -> { 'https://example.jira.com/browse/%s' }
    set :committed_deployments,       -> { false }
    set :committed_deployment_id,     -> { nil }
  end
end
