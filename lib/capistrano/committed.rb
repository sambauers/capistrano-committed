require 'capistrano/committed/version'
require 'capistrano/committed/i18n'
require 'capistrano/committed/github_api'
require 'capistrano/committed/output'

module Capistrano
  module Committed
    class << self
      @@settings = {}

      def import_settings(settings, merge = nil)
        merge.nil? ? @@settings = settings : @@settings.merge!(settings)
      end

      def get_setting(setting, variable = nil)
        variable.nil? ? @@settings[setting] : variable
      end

      def revision_search_regex(revision_line = nil)
        revision_line = get_setting(:revision_line, revision_line)
        check_type __callee__, 'revision_line', revision_line.is_a?(String)

        search = Regexp.escape(revision_line)
        search = search.gsub('%\{', '(?<').gsub('\}', '>.+)')
        Regexp.new(search)
      end

      def get_revisions_from_lines(lines, search = nil, branch = nil, limit = nil)
        check_type __callee__, 'lines', lines.is_a?(Array)
        lines.each_with_index do |line, index|
          check_type __callee__, format('lines[%<index>d]', index: index), line.is_a?(String)
        end

        search = revision_search_regex if search.nil?
        check_type __callee__, 'search', search.is_a?(Regexp)

        branch = get_setting(:branch, branch)
        check_type __callee__, 'branch', (branch.is_a?(Symbol) || branch.is_a?(String))

        limit = get_setting(:revision_limit, limit)
        check_type __callee__, 'limit', limit.is_a?(Integer)

        revisions = {}
        lines.each do |line|
          matches = search.match(line)
          next if matches.nil?
          next unless matches[:branch].to_s == branch.to_s
          revisions[matches[:release]] = {
            branch:   matches[:branch],
            sha:      matches[:sha],
            release:  matches[:release],
            user:     matches[:user],
            entries:  {}
          }
          # Only store a certain number of revisions
          break if revisions.count == limit
        end
        pad_revisions(revisions)
      end

      def add_dates_to_revisions(revisions, github, git_user = nil, git_repo = nil)
        check_type __callee__, 'revisions', revisions.is_a?(Hash)
        check_type __callee__, 'github', github.is_a?(Capistrano::Committed::GithubApi)
        git_user = check_git_user(git_user)
        git_repo = check_git_repo(git_repo)

        revisions.each do |release, revision|
          next if %i[next previous].include? release
          commit = github.get_commit(git_user, git_repo, revision[:sha])
          revisions[release][:date] = commit[:commit][:committer][:date] unless commit.nil?
        end
      end

      def get_earliest_date_from_revisions(revisions)
        check_type __callee__, 'revisions', revisions.is_a?(Hash)

        revisions.values.map { |r| Time.parse(r[:date]) unless r[:date].nil? }.compact.min
      end

      def days_to_seconds(days)
        check_type __callee__, 'days', days.is_a?(Numeric)

        days * 24 * 60 * 60
      end

      def add_buffer_to_time(time, buffer_in_days = nil)
        check_type __callee__, 'time', time.is_a?(Time)

        buffer_in_days = get_setting(:commit_buffer, buffer_in_days)
        check_type __callee__, 'buffer_in_days', buffer_in_days.is_a?(Numeric)

        (time - days_to_seconds(buffer_in_days)).iso8601
      end

      def get_issue_urls(message, issue_match = nil, issue_postprocess = nil, issue_url = nil)
        check_type __callee__, 'message', message.is_a?(String)
        issue_match = check_issue_match(issue_match)
        issue_postprocess = check_issue_postprocess(issue_postprocess)
        issue_url = check_issue_url(issue_url)

        return [] unless (matches = message.scan(Regexp.new(issue_match)))
        matches.map! do |match|
          postprocess_issue_url(issue_postprocess, issue_url, match[0])
        end.uniq
      end

      private

      def check_type(method, param, condition)
        raise TypeError, t('committed.error.helpers.valid_param', method: method, param: param) unless condition
      end

      def check_git_user(git_user)
        git_user = get_setting(:user, git_user)
        check_type __callee__, 'git_user', git_user.is_a?(String)
        git_user
      end

      def check_git_repo(git_repo)
        git_repo = get_setting(:repo, git_repo)
        check_type __callee__, 'git_repo', git_repo.is_a?(String)
        git_repo
      end

      def check_issue_match(issue_match)
        issue_match = get_setting(:issue_match, issue_match)
        check_type __callee__, 'issue_match', (issue_match.is_a?(String) || issue_match.is_a?(Regexp))
        issue_match
      end

      def check_issue_postprocess(issue_postprocess)
        issue_postprocess = get_setting(:issue_postprocess, issue_postprocess)
        check_type __callee__, 'issue_postprocess', issue_postprocess.is_a?(Array)
        issue_postprocess.each do |method|
          check_type __callee__, format('issue_postprocess[:%<method>s]', method: method.to_s), method.is_a?(Symbol)
        end
        issue_postprocess
      end

      def check_issue_url(issue_url)
        issue_url = get_setting(:issue_url, issue_url)
        check_type __callee__, 'issue_url', issue_url.is_a?(String)
        issue_url
      end

      def postprocess_issue_url(issue_postprocess, issue_url, issue)
        issue_postprocess.each { |method| issue = issue.send(method) }
        format(issue_url, issue)
      end

      def pad_revisions(revisions)
        check_type __callee__, 'revisions', revisions.is_a?(Hash)

        unless revisions.empty?
          # Sort revisions by release date
          revisions = Hash[revisions.sort { |a, b| b[1][:release] <=> a[1][:release] }]
          # Add the "previous" revision
          revisions[:previous] = { release: :previous, entries: {} }
          # Add the "next" revision
          revisions = { next: { release: :next, entries: {} } }.merge(revisions)
        end
        revisions
      end
    end
  end
end

load File.expand_path('tasks/committed.rake', __dir__)
