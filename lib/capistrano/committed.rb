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
        matches.map { |match|
          issue = match[0]
          postprocess.each { |method|
            issue = issue.send(method)
          }
          format(url_pattern, issue)
        }
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
          revisions = revisions.sort_by { |_release, matches| matches[:release] }.to_h
          # Add the "next" revision
          revisions.merge!(next: { entries: {} })
          # Reverse the order of revisions in the hash (most recent first)
          revisions = revisions.to_a.reverse.to_h
          revisions.merge!(previous: { entries: {} })
        end
        revisions.to_h
      end
    end
  end
end

load File.expand_path('../tasks/committed.rake', __FILE__)
