require 'capistrano/committed/version'
require 'capistrano/committed/i18n'
require 'capistrano/committed/github_api'

module Capistrano
  module Committed
    class << self
      def revision_search_regex(revision_line)
        check_type __callee__, 'revision_line', revision_line.is_a?(String)

        search = Regexp.escape(revision_line)
        search = search.gsub('%\{', '(?<').gsub('\}', '>.+)')
        Regexp.new(search)
      end

      def get_revisions_from_lines(lines, search, branch, limit)
        check_type __callee__, 'lines', lines.is_a?(Array)
        lines.each_with_index { |line, index|
          check_type __callee__,
                     format('lines[%d]', index),
                     line.is_a?(String)
        }
        check_type __callee__, 'search', search.is_a?(Regexp)
        check_type __callee__, 'branch', branch.is_a?(String)
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

      def add_dates_to_revisions(revisions, github, git_user, git_repo)
        check_type __callee__, 'revisions', revisions.is_a?(Hash)
        check_type __callee__, 'github', github.is_a?(Capistrano::Committed::GithubApi)
        check_type __callee__, 'git_user', git_user.is_a?(String)
        check_type __callee__, 'git_repo', git_repo.is_a?(String)

        revisions.each do |release, revision|
          next if release == :next || release == :previous
          commit = github.get_commit(git_user,
                                     git_repo,
                                     revision[:sha])
          unless commit.nil?
            revisions[release][:date] = commit[:commit][:committer][:date]
          end
        end
        revisions
      end

      def get_earliest_date_from_revisions(revisions)
        check_type __callee__, 'revisions', revisions.is_a?(Hash)

        revisions.values.map{ |r| Time.parse(r[:date]) unless r[:date].nil? }.compact.min
      end

      def days_to_seconds(days)
        check_type __callee__, 'days', days.is_a?(Numeric)

        days * 24 * 60 * 60
      end

      def add_buffer_to_time(time, buffer_in_days)
        check_type __callee__, 'time', time.is_a?(Time)
        check_type __callee__, 'buffer_in_days', buffer_in_days.is_a?(Numeric)

        (time - days_to_seconds(buffer_in_days)).iso8601
      end

      def format_revision_header(release, revision)
        check_type __callee__, 'release', (release.is_a?(Symbol) || release.is_a?(String))
        check_type __callee__, 'revision', revision.is_a?(Hash)

        output = ['']
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
      end

      def format_commit(commit, pad, issue_pattern, postprocess, url_pattern)
        check_type __callee__, 'commit', commit.is_a?(Hash)
        check_type __callee__, 'pad', pad.is_a?(String)
        # issue_pattern, postprocess, and url_pattern get type checked by `get_issue_urls`

        # Print the commit ref
        output = [format('%s * %s',
                         pad,
                         t('committed.output.commit_sha',
                           sha: commit[:sha]))]
        output << pad

        # Print the commit message
        lines = commit[:commit][:message].chomp.split("\n")
        unless lines.empty?
          lines.each do |line|
            output << format('%s   > %s',
                             pad,
                             line)
          end
          output << pad

          # Get any issue numbers referred to in the commit message
          # and print links to them
          urls = get_issue_urls(issue_pattern,
                                postprocess,
                                url_pattern,
                                commit[:commit][:message])
          output += format_issue_urls(urls, pad)
        end

        # Committer details
        output << format('%s   %s',
                         pad,
                         t('committed.output.committed_on',
                           time: commit[:commit][:committer][:date]))
        output << format('%s   %s',
                         pad,
                         t('committed.output.committed_by',
                           login: commit[:committer][:login]))
        output << pad

        # Print a link to the commit in GitHub
        output << format('%s   %s', pad, commit[:html_url])
        output << pad
      end

      def get_issue_urls(issue_pattern, postprocess, url_pattern, message)
        check_type __callee__,
                   'issue_pattern',
                   (issue_pattern.is_a?(String) || issue_pattern.is_a?(Regexp))

        check_type __callee__, 'postprocess', postprocess.is_a?(Array)
        postprocess.each { |method|
          check_type __callee__,
                     format('postprocess[:%s]', method.to_s),
                     method.is_a?(Symbol)
        }

        check_type __callee__, 'url_pattern', url_pattern.is_a?(String)
        check_type __callee__, 'message', message.is_a?(String)

        matches = message.scan(Regexp.new(issue_pattern))
        return [] unless matches
        matches.map! { |match|
          issue = match[0]
          postprocess.each { |method|
            issue = issue.send(method)
          }
          format(url_pattern, issue)
        }
        matches.uniq
      end

      def format_issue_urls(urls, pad = '')
        return [] if urls.nil? || urls.empty?
        output = []
        output << format('%s   %s', pad, t('committed.output.issue_links'))
        urls.each do |url|
          output << format('%s   - %s', pad, url)
        end
        output << format('%s', pad)
      end

    private
      def check_type(method, param, condition)
        fail TypeError, t('committed.error.helpers.valid_param',
                        method: method,
                        param: param) unless condition
      end

      def pad_revisions(revisions)
        check_type __callee__, 'revisions', revisions.is_a?(Hash)

        unless revisions.empty?
          # Sort revisions by release date
          revisions = Hash[revisions.sort { |a, b| b[1][:release] <=> a[1][:release] }]
          # Add the "previous" revision
          revisions.merge!(previous: { entries: {} })
          # Add the "next" revision
          revisions = {next: { entries: {} }}.merge(revisions)
        end
        revisions
      end
    end
  end
end

load File.expand_path('../tasks/committed.rake', __FILE__)
