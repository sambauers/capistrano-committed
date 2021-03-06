namespace :committed do
  task :check_prerequisites do
    # Checks all the settings to make sure they are OK - mostly just checks type
    { committed_user: 'user', committed_repo: 'repository' }.each do |variable, name|
      if fetch(variable).nil? || !fetch(variable).is_a?(String)
        raise TypeError, t('committed.error.prerequisites.nil', variable: variable, name: name)
      end
      if fetch(variable).empty?
        raise ArgumentError, t('committed.error.prerequisites.empty', variable: variable, name: name)
      end
    end

    unless fetch(:committed_github_config).is_a?(Hash)
      raise TypeError, t('committed.error.prerequisites.hash', variable: 'committed_github_config')
    end
  end

  task :check_report_prerequisites do
    # Checks all the settings to make sure they are OK - mostly just checks type
    unless fetch(:committed_revision_line).is_a?(String)
      raise TypeError, t('committed.error.prerequisites.string', variable: 'committed_revision_line')
    end

    unless fetch(:committed_revision_limit).is_a?(Integer)
      raise TypeError, t('committed.error.prerequisites.integer', variable: 'committed_revision_limit')
    end

    unless fetch(:committed_commit_buffer).is_a?(Integer)
      raise TypeError, t('committed.error.prerequisites.integer', variable: 'committed_commit_buffer')
    end

    if fetch(:committed_output_path).is_a?(String)
      raise TypeError, t('committed.error.deprecated', deprecated: 'committed_output_path', replacement: 'committed_output_text_path')
    end

    unless fetch(:committed_output_text_path).is_a?(String) || fetch(:committed_output_text_path).nil?
      raise TypeError, t('committed.error.prerequisites.string_or_nil', variable: 'committed_output_text_path')
    end

    unless fetch(:committed_output_html_path).is_a?(String) || fetch(:committed_output_html_path).nil?
      raise TypeError, t('committed.error.prerequisites.string_or_nil', variable: 'committed_output_html_path')
    end

    unless fetch(:committed_issue_match).is_a?(String) || fetch(:committed_issue_match).is_a?(Regexp) || fetch(:committed_issue_match).nil?
      raise TypeError, t('committed.error.prerequisites.string_or_regexp_or_nil', variable: 'committed_issue_match')
    end

    unless fetch(:committed_issue_url).is_a?(String) || fetch(:committed_issue_url).nil?
      raise TypeError, t('committed.error.prerequisites.string_or_nil', variable: 'committed_issue_url')
    end
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

    ::Capistrano::Committed.import_settings(
      branch:            fetch(:branch),
      user:              fetch(:committed_user),
      repo:              fetch(:committed_repo),
      revision_line:     fetch(:committed_revision_line),
      github_config:     fetch(:committed_github_config),
      revision_limit:    fetch(:committed_revision_limit),
      commit_buffer:     fetch(:committed_commit_buffer),
      output_text_path:  fetch(:committed_output_text_path),
      output_html_path:  fetch(:committed_output_html_path),
      issue_match:       fetch(:committed_issue_match),
      issue_postprocess: fetch(:committed_issue_postprocess),
      issue_url:         fetch(:committed_issue_url),
      deployments:       fetch(:committed_deployments),
      deployment_id:     fetch(:committed_deployment_id)
    )

    # Only do this on the primary web server
    on primary :web do
      # Get the Capistrano revision log
      lines = capture(:cat, revision_log).split("\n").reverse

      # Build the revisions hash
      revisions = ::Capistrano::Committed.get_revisions_from_lines(lines)

      # No revisions, no log
      if revisions.empty?
        error t('committed.error.runtime.revisions_empty',
                branch: fetch(:branch).to_s,
                stage: fetch(:stage).to_s)
      end

      # Initialize the GitHub API client
      github = ::Capistrano::Committed::GithubApi.new(fetch(:committed_github_config))

      # Get the actual date of the commit referenced to by the revision
      revisions = ::Capistrano::Committed.add_dates_to_revisions(revisions, github)

      # Get the earliest revision date
      earliest_date = ::Capistrano::Committed.get_earliest_date_from_revisions(revisions)

      # No commit data on revisions, no log
      if earliest_date.nil?
        error t('committed.error.runtime.revision_commit_missing',
                branch: fetch(:branch).to_s,
                stage: fetch(:stage).to_s)
      end

      # Go back an extra N days
      earliest_date = ::Capistrano::Committed.add_buffer_to_time(earliest_date)
      revisions[:previous][:date] = earliest_date

      # Get all the commits on this branch
      commits = github.get_commits_since(fetch(:committed_user),
                                         fetch(:committed_repo),
                                         earliest_date,
                                         fetch(:branch).to_s)

      # No commits, no log
      if commits.empty?
        error t('committed.error.runtime.commits_empty',
                branch: fetch(:branch).to_s,
                stage: fetch(:stage).to_s,
                time: earliest_date)
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
        sub_commits = []
        pull_request[:commits].each do |c|
          sub_commits << {
            type: :commit,
            info: c
          }
        end
        revisions[key][:entries][pull_request[:info][:merged_at]] = [{
          type:     :pull_request,
          info:     pull_request[:info],
          commits:  sub_commits
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

      # Send the text output to screen, or to a file on the server

      # Create the mustache instance and plug in the revisions
      output = ::Capistrano::Committed::Output.new
      output[:revisions] = revisions.values
      output[:page_title] = t('committed.output.page_title',
                              repo: format('%<user>s/%<repo>s',
                                           user: fetch(:committed_user),
                                           repo: fetch(:committed_repo)))

      # Send the text output to a file on the server
      if fetch(:committed_output_text_path).nil?
        # Just print to STDOUT
        puts output.render
      else
        # Determine the output path and upload the output there
        output_text_path = format(fetch(:committed_output_text_path), current_path)
        upload! StringIO.new(output.render), output_text_path

        # Make sure the report is world readable
        execute(:chmod, 'a+r', output_text_path)
      end

      # Send the html output to a file on the server
      unless fetch(:committed_output_html_path).nil?
        # Switch to the HTML template
        output.template_file = output.get_output_template_path('html')

        # Determine the output path and upload the output there
        output_html_path = format(fetch(:committed_output_html_path), current_path)
        upload! StringIO.new(output.render), output_html_path

        # Make sure the report is world readable
        execute(:chmod, 'a+r', output_html_path)
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
    set :committed_output_text_path,  -> { '%s/public/committed.txt' }
    set :committed_output_html_path,  -> { '%s/public/committed.html' }
    set :committed_issue_match,       -> { '\[\s?([a-zA-Z0-9]+\-[0-9]+)\s?\]' }
    set :committed_issue_postprocess, -> { [] }
    set :committed_issue_url,         -> { 'https://example.jira.com/browse/%s' }
    set :committed_deployments,       -> { false }
    set :committed_deployment_id,     -> { nil }
  end
end
