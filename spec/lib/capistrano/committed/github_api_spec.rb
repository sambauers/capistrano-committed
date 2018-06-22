require 'spec_helper'

module Capistrano
  module Committed
    describe GithubApi do
      let(:object) { described_class }
      subject(:github_api) { object.new }

      let(:user) { 'octocat' }
      let(:repo) { 'Hello-World' }
      let(:sha) { '7638417' }
      let(:sha_full) { '7638417db6d59f3c431d3e1f261cc637155684cd' }
      let(:date) { '2015-08-10T08:00:00Z' }
      let(:stage) { 'production' }
      let(:status) { 'pending' }
      let(:method) { 'is_rspec_test?' }

      describe 'initialize' do
        it 'fails if config_options is not a Hash' do
          expect { object.new(nil) }.to raise_error TypeError
        end
      end

      describe 'client' do
        let(:subject_with_options) { object.new(hello: 'there', user_agent: 'Foo bar agent') }

        it 'returns a valid Github::Client object' do
          expect(subject.client).to be_a Github::Client
          expect(subject.client.current_options).to be_a Hash
          expect(subject.client.current_options[:adapter]).to eq :net_http
        end

        it 'returns a valid Github::Client object with custom options' do
          expect(subject_with_options.client).to be_a Github::Client
          expect(subject_with_options.client.current_options).to be_a Hash
          expect(subject_with_options.client.current_options[:adapter]).to eq :net_http
          expect(subject_with_options.client.current_options[:hello]).to eq 'there'
          expect(subject_with_options.client.current_options[:user_agent]).to eq 'Foo bar agent'
        end
      end

      describe 'get_commit' do
        it 'fails if user is not a String' do
          expect { subject.get_commit(nil, repo, sha) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect { subject.get_commit(user, nil, sha) }.to raise_error TypeError
        end

        it 'fails if sha is not a String' do
          expect { subject.get_commit(user, repo, nil) }.to raise_error TypeError
        end
      end

      describe 'get_commits_since' do
        it 'fails if user is not a String' do
          expect { subject.get_commits_since(nil, repo, date) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect { subject.get_commits_since(user, nil, date) }.to raise_error TypeError
        end

        it 'fails if date is nil' do
          expect { subject.get_commits_since(user, repo, nil) }.to raise_error TypeError
        end

        it 'fails if date is not parsed to a Time' do
          expect { subject.get_commits_since(user, repo, 'fred') }.to raise_error ArgumentError
        end

        it 'fails if branch is not a String' do
          expect { subject.get_commits_since(user, repo, date, nil) }.to raise_error TypeError
        end
      end

      describe 'get_pull_request' do
        it 'fails if user is not a String' do
          expect { subject.get_pull_request(nil, repo, 1) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect { subject.get_pull_request(user, nil, 1) }.to raise_error TypeError
        end

        it 'fails if number is not an Integer' do
          expect { subject.get_pull_request(user, repo, nil) }.to raise_error TypeError
        end
      end

      describe 'register_deployment' do
        it 'fails if user is not a String' do
          expect { subject.register_deployment(nil, repo, stage) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect { subject.register_deployment(user, nil, stage) }.to raise_error TypeError
        end

        it 'fails if stage is not a String' do
          expect { subject.register_deployment(user, repo, nil) }.to raise_error TypeError
        end

        it 'fails if branch is not a String' do
          expect { subject.register_deployment(user, repo, stage, nil) }.to raise_error TypeError
        end
      end

      describe 'register_deployment_status' do
        it 'fails if user is not a String' do
          expect { subject.register_deployment_status(nil, repo, 123, status) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect { subject.register_deployment_status(user, nil, 123, status) }.to raise_error TypeError
        end

        it 'fails if id is not an Integer' do
          expect { subject.register_deployment_status(user, repo, nil, status) }.to raise_error TypeError
        end

        it 'fails if state is not valid' do
          expect { subject.register_deployment_status(user, repo, 123, 'foo') }.to raise_error TypeError
        end
      end

      describe 'validate' do
        it 'fails if passed a string when it wants an Integer' do
          expect { subject.send(:validate, 'test', 'my_string', Integer, method) }.to raise_error TypeError
        end
      end

      describe 'validate_user_and_repo' do
        it 'fails if user is not a String' do
          expect { subject.send(:validate_user_and_repo, nil, repo, method) }.to raise_error TypeError
        end

        it 'fails if repo is not a String' do
          expect { subject.send(:validate_user_and_repo, user, nil, method) }.to raise_error TypeError
        end
      end
    end
  end
end
