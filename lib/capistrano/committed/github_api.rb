require 'github_api'

module Capistrano
  module Committed
    class GithubApi
      def initialize(config_options = {})
        validate('config_options', config_options, Hash, __callee__)

        options = { adapter: :net_http,
                    ssl: { verify: false },
                    per_page: 100,
                    user_agent: 'Committed Ruby Gem (via Github API Ruby Gem)' }

        options.merge! config_options

        @client = ::Github.new options
      end

      def client
        @client
      end

      def get_commit(user, repo, sha)
        validate_user_and_repo(user, repo, __callee__)
        validate('sha', sha, String, __callee__)

        api_call do
          @client.repos.commits.get(user: user,
                                    repo: repo,
                                    sha:  sha)
        end
      end

      def get_commits_since(user, repo, date, branch = 'master')
        validate_user_and_repo(user, repo, __callee__)
        date = Time.parse(date) if date.is_a?(String)
        validate('date', date, Time, __callee__)
        validate('branch', branch, String, __callee__)

        api_call do
          @client.repos.commits.list(user:  user,
                                     repo:  repo,
                                     sha:   branch,
                                     since: date.iso8601)
        end
      end

      def get_pull_request(user, repo, number)
        validate_user_and_repo(user, repo, __callee__)
        validate('number', number, Integer, __callee__)

        api_call do
          info = @client.pull_requests.get(user:    user,
                                           repo:    repo,
                                           number:  number)

          commits = @client.pull_requests.commits(user:   user,
                                                  repo:   repo,
                                                  number: number)

          return { info: info, commits: commits }
        end
      end

      def register_deployment(user, repo, stage, branch = 'master')
        validate_user_and_repo(user, repo, __callee__)
        validate('stage', stage, String, __callee__)
        validate('branch', branch, String, __callee__)

        api_call do
          @client.repos.deployments.create(user:              user,
                                           repo:              repo,
                                           environment:       stage,
                                           ref:               branch,
                                           auto_merge:        false,
                                           required_contexts: [])
        end
      end

      def register_deployment_status(user, repo, id, state)
        validate_user_and_repo(user, repo, __callee__)
        validate('id', id, Integer, __callee__)

        valid_states = %w(pending success error failure)
        state = state.to_s
        unless valid_states.include?(state)
          message = t('committed.error.helpers.valid_param',
                      method: __callee__,
                      param: 'state')
          fail TypeError, message
        end

        api_call do
          @client.repos.deployments.create_status(user:   user,
                                                  repo:   repo,
                                                  id:     id,
                                                  state:  state)
        end
      end

      private

      def validate(param, value, type, method)
        return if value.is_a?(type)
        message = t('committed.error.helpers.valid_param',
                    method: method,
                    param: param)
        fail TypeError, message
      end

      def validate_user_and_repo(user, repo, method)
        validate('GitHub user', user, String, method)
        validate('GitHub repository', repo, String, method)
      end

      def api_call
        yield
      rescue ::Github::Error::GithubError => e
        if e.is_a? ::Github::Error::ServiceError
          raise e, t('committed.error.helpers.github_service_error')
        elsif e.is_a? ::Github::Error::ClientError
          raise e, t('committed.error.helpers.github_client_error')
        end
      end
    end
  end
end
