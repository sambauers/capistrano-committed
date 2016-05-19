require 'i18n'

en = {
  error: {
    helpers: {
      valid_param:          '`%{method}` requires a valid %{param}.',
      github_service_error: 'There seems to be a problem with the GitHub service.',
      github_client_error:  'There seems to be a problem with the request that was made to GitHub, check that your settings are correct.'
    },
    prerequisites: {
      nil:                      '`:%{variable}` variable is `nil`, it needs to contain the %{name} name.',
      empty:                    '`:%{variable}` variable is empty, it needs to contain the %{name} name.',
      string:                   '`:%{variable}` variable is not a string.',
      hash:                     '`:%{variable}` variable is not a hash.',
      integer:                  '`:%{variable}` variable is not a integer.',
      string_or_nil:            '`:%{variable}` variable is not a string or `nil`.',
      string_or_regexp_or_nil:  '`:%{variable}` variable is not a string or `Regexp` object or `nil`.'
    },
    deprecated: '`%{deprecated}` variable is deprecated. Use `%{replacement}` instead.',
    runtime: {
      revisions_empty:          'The %{branch} branch has never been deployed to the %{stage} stage. No log has been generated.',
      revision_commit_missing:  'No commit data has been found for the %{branch} branch on the %{stage} stage. No log has been generated.',
      commits_empty:            'No commit data has been found for the %{branch} branch on the %{stage} stage since %{time}. No log has been generated.'
    }
  },
  output: {
    page_title:           'Git Deployment Report for %{repo}',
    next_release:         'Next release',
    previous_release:     'Commits before %{time} are omitted from the report   ¯\_(ツ)_/¯',
    current_release:      'Release on %{release_time} from commit %{sha} at %{commit_time}',
    pull_request_number:  'Pull Request #%{number}',
    issue_links:          'Issue links:',
    merged_on:            'Merged on: %{time}',
    merged_by:            'Merged by: %{login}',
    commit_sha:           'Commit %{sha}',
    committed_on:         'Committed on: %{time}',
    committed_by:         'Committed by: %{login}'
  }
}

I18n.backend.store_translations(:en, { capistrano: { committed: en } })

if I18n.respond_to?(:enforce_available_locales=)
  I18n.enforce_available_locales = true
end
