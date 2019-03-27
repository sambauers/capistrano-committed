require 'i18n'

en = {
  error: {
    helpers: {
      valid_param:          '`%<method>s` requires a valid %<param>s.',
      github_service_error: 'There seems to be a problem with the GitHub service.',
      github_client_error:  'There seems to be a problem with the request that was made to GitHub, check that your settings are correct.'
    },
    prerequisites: {
      nil:                      '`:%<variable>s` variable is `nil`, it needs to contain the %<name>s name.',
      empty:                    '`:%<variable>s` variable is empty, it needs to contain the %<name>s name.',
      string:                   '`:%<variable>s` variable is not a string.',
      hash:                     '`:%<variable>s` variable is not a hash.',
      integer:                  '`:%<variable>s` variable is not a integer.',
      string_or_nil:            '`:%<variable>s` variable is not a string or `nil`.',
      string_or_regexp_or_nil:  '`:%<variable>s` variable is not a string or `Regexp` object or `nil`.'
    },
    deprecated: '`%<deprecated>s` variable is deprecated. Use `%<replacement>s` instead.',
    runtime: {
      revisions_empty:          'The %<branch>s branch has never been deployed to the %<stage>s stage. No log has been generated.',
      revision_commit_missing:  'No commit data has been found for the %<branch>s branch on the %<stage>s stage. No log has been generated.',
      commits_empty:            'No commit data has been found for the %<branch>s branch on the %<stage>s stage since %<time>s. No log has been generated.'
    }
  },
  output: {
    page_title:           'Git Deployment Report for %<repo>s',
    next_release:         'Next release',
    previous_release:     'Commits before %<time>s are omitted from the report   ¯\_(ツ)_/¯',
    current_release:      'Release on %<release_time>s from commit %<sha>s at %<commit_time>s',
    pull_request_number:  'Pull Request #%<number>s',
    issue_links:          'Issue links:',
    merged_on:            'Merged on: %<time>s',
    merged_by:            'Merged by: %<login>s',
    commit_sha:           'Commit %<sha>s',
    committed_on:         'Committed on: %<time>s',
    committed_by:         'Committed by: %<login>s'
  }
}

I18n.backend.store_translations(:en, capistrano: { committed: en })

if I18n.respond_to?(:enforce_available_locales=)
  I18n.enforce_available_locales = true
end
