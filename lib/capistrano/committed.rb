require "capistrano/committed/version"
require 'capistrano/committed/i18n'
require "capistrano/committed/github_api"

module Capistrano
  module Committed
    class << self
      def scan_for_issues(pattern, string)
        raise TypeError, sprintf('`%s` requires a valid pattern.', __callee__) unless pattern.is_a?(String) || pattern.is_a?(Regexp)
        raise TypeError, sprintf('`%s` requires a valid string.', __callee__) unless pattern.is_a?(String)

        matches = Regexp.new(pattern).match(string)
        return unless matches && matches[1]
        matches = matches.to_a
        matches.shift
        matches
      end
    end
  end
end

load File.expand_path("../tasks/committed.rake", __FILE__)
