require 'spec_helper'

module Capistrano
  module Committed
    describe GithubApi do
      before(:each) do
        @github_empty = GithubApi.new
        @github_with_options = GithubApi.new(hello: 'there',
                                             user_agent: 'Foo bar agent')
        @user = 'user'
        @repo = 'repo'
        @sha = '1234567890abcdef'
        @date = '2015-08-10T08:00:00Z'
        @stage = 'production'
        @status = 'pending'
        @method = 'is_rspec_test?'
      end

      describe 'initialize' do
        it 'fails if config_options is not a Hash' do
          expect{ GithubApi.new(nil) }.to raise_error TypeError
        end
      end

      describe 'client' do
        it 'returns a valid Github::Client object' do
          expect(@github_empty.client).to be_a Github::Client
          expect(@github_empty.client.current_options).to be_a Hash
          expect(@github_empty.client.current_options[:adapter]).to eq :net_http
        end

        it 'returns a valid Github::Client object with custom options' do
          expect(@github_with_options.client).to be_a Github::Client
          expect(@github_with_options.client.current_options).to be_a Hash
          expect(@github_with_options.client.current_options[:adapter]).to eq :net_http
          expect(@github_with_options.client.current_options[:hello]).to eq 'there'
          expect(@github_with_options.client.current_options[:user_agent]).to eq 'Foo bar agent'
        end
      end

      describe 'get_commit' do
        it 'fails if user is not a String' do
          expect{ @github_empty.get_commit(nil, @repo, @sha) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect{ @github_empty.get_commit(@user, nil, @sha) }.to raise_error TypeError
        end

        it 'fails if sha is not a String' do
          expect{ @github_empty.get_commit(@user, @repo, nil) }.to raise_error TypeError
        end
      end

      describe 'get_commits_since' do
        it 'fails if user is not a String' do
          expect{ @github_empty.get_commits_since(nil, @repo, @date) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect{ @github_empty.get_commits_since(@user, nil, @date) }.to raise_error TypeError
        end

        it 'fails if date is nil' do
          expect{ @github_empty.get_commits_since(@user, @repo, nil) }.to raise_error TypeError
        end

        it 'fails if date is not parsed to a Time' do
          expect{ @github_empty.get_commits_since(@user, @repo, 'fred') }.to raise_error ArgumentError
        end

        it 'fails if branch is not a String' do
          expect{ @github_empty.get_commits_since(@user, @repo, @date, nil) }.to raise_error TypeError
        end
      end

      describe 'get_pull_request' do
        it 'fails if user is not a String' do
          expect{ @github_empty.get_pull_request(nil, @repo, 1) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect{ @github_empty.get_pull_request(@user, nil, 1) }.to raise_error TypeError
        end

        it 'fails if number is not an Integer' do
          expect{ @github_empty.get_pull_request(@user, @repo, nil) }.to raise_error TypeError
        end
      end

      describe 'register_deployment' do
        it 'fails if user is not a String' do
          expect{ @github_empty.register_deployment(nil, @repo, @stage) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect{ @github_empty.register_deployment(@user, nil, @stage) }.to raise_error TypeError
        end

        it 'fails if stage is not a String' do
          expect{ @github_empty.register_deployment(@user, @repo, nil) }.to raise_error TypeError
        end

        it 'fails if branch is not a String' do
          expect{ @github_empty.register_deployment(@user, @repo, @stage, nil) }.to raise_error TypeError
        end
      end

      describe 'register_deployment_status' do
        it 'fails if user is not a String' do
          expect{ @github_empty.register_deployment_status(nil, @repo, 123, @status) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect{ @github_empty.register_deployment_status(@user, nil, 123, @status) }.to raise_error TypeError
        end

        it 'fails if id is not an Integer' do
          expect{ @github_empty.register_deployment_status(@user, @repo, nil, @status) }.to raise_error TypeError
        end

        it 'fails if state is not valid' do
          expect{ @github_empty.register_deployment_status(@user, @repo, 123, 'foo') }.to raise_error TypeError
        end
      end

      describe 'validate' do
        it 'fails if passed a string when it wants an Integer' do
          expect{ @github_empty.send(:validate, 'test', 'my_string', Integer, @method) }.to raise_error TypeError
        end
      end

      describe 'validate_user_and_repo' do
        it 'fails if user is not a String' do
          expect{ @github_empty.send(:validate_user_and_repo, nil, @repo, @method) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect{ @github_empty.send(:validate_user_and_repo, @user, nil, @method) }.to raise_error TypeError
        end
      end
    end
  end
end
