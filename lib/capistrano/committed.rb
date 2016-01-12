require 'capistrano/committed/version'
require 'capistrano/committed/i18n'
require 'capistrano/committed/github_api'

module Capistrano
  module Committed
    class << self
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
    end
  end
end

load File.expand_path('../tasks/committed.rake', __FILE__)
