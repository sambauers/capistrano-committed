require 'github_api'

module Capistrano
  module Committed
    class GithubApi
      def initialize(config_options = {})
        raise TypeError, '`initialize` requires a hash to be passed as the first and only argument' unless config_options.is_a?(Hash)

        config_options.merge!({
          :adapter => :net_http,
          :ssl => {:verify => false},
          :per_page => 100,
          :user_agent => 'Committed Ruby Gem (via Github API Ruby Gem)'
        })

        @client = ::Github.new config_options
      end

      def get_commit(user, repo, sha)
        validate_user_and_repo(user, repo)
        raise TypeError, sprintf('`%s` requires a valid commit SHA.', __callee__) unless sha.is_a?(String)

        begin
          @client.repos.commits.get(:user => user, :repo => repo, :sha => sha)
        rescue ::Github::Error::GithubError => e
          rescue_github_errors(e)
        end
      end

      def get_commits_since(user, repo, date, branch = 'master')
        validate_user_and_repo(user, repo)
        date = Time.parse(date) if date.is_a?(String)
        raise TypeError, sprintf('`%s` requires a valid date.', __callee__) unless date.is_a?(Time)
        raise TypeError, sprintf('`%s` requires a valid branch.', __callee__) unless branch.is_a?(String)

        begin
          @client.repos.commits.list(:user => user, :repo => repo, :sha => branch, :since => date.iso8601)
        rescue ::Github::Error::GithubError => e
          rescue_github_errors(e)
        end
      end

      def get_pull_request(user, repo, number)
        validate_user_and_repo(user, repo)
        raise TypeError, sprintf('`%s` requires a valid pull request number.', __callee__) unless number.is_a?(Integer)

        begin
          info = @client.pull_requests.get(:user => user, :repo => repo, :number => number)
          commits = @client.pull_requests.commits(:user => user, :repo => repo, :number => number)
          return {:info => info, :commits => commits}
        rescue ::Github::Error::GithubError => e
          rescue_github_errors(e)
        end
      end

      def validate_user_and_repo(user, repo)
        raise TypeError, sprintf('`%s` requires a valid GitHub user.', __caller__) unless user.is_a?(String)
        raise TypeError, sprintf('`%s` requires a valid GitHub repository.', __caller__) unless repo.is_a?(String)
      end

      def rescue_github_errors(e)
        if e.is_a? ::Github::Error::ServiceError
          raise e, 'There seems to be a problem with the GitHub service.'
        elsif e.is_a? ::Github::Error::ClientError
          raise e, 'There seems to be a problem with the request that was made to GitHub, check that your settings are correct.'
        end
      end
    end
  end
end
