require 'spec_helper'

describe Capistrano::Committed::GithubApi do
  describe 'initialize' do
    it 'fails if config_options is not a Hash' do
      expect{ Capistrano::Committed::GithubApi.new(nil) }.to raise_error TypeError
    end
  end

  describe 'client' do
    let(:github) { Capistrano::Committed::GithubApi.new }

    it 'returns a valid Github::Client object' do
      expect(github.client).to be_a Github::Client
      expect(github.client.current_options).to be_a Hash
      expect(github.client.current_options[:adapter]).to eq :net_http
    end

    let(:github_with_options) { Capistrano::Committed::GithubApi.new({ hello: 'there', user_agent: 'Foo bar agent' }) }

    it 'returns a valid Github::Client object with custom options' do
      expect(github_with_options.client).to be_a Github::Client
      expect(github_with_options.client.current_options).to be_a Hash
      expect(github_with_options.client.current_options[:adapter]).to eq :net_http
      expect(github_with_options.client.current_options[:hello]).to eq 'there'
      expect(github_with_options.client.current_options[:user_agent]).to eq 'Foo bar agent'
    end
  end
end
