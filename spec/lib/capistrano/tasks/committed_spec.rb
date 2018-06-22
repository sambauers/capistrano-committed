require 'spec_helper'

context 'rake tasks' do
  let(:rake)      { Rake::Application.new }
  let(:task_name) do
    format('%<superklass>s:%<klass>s',
           superklass: self.class.superclass.description,
           klass: self.class.description)
  end
  subject         { rake[task_name] }
  let(:dsl)       { Class.new.extend Capistrano::DSL }

  before do
    Rake.application = rake
    Rake.application.rake_require('committed', [tasks_path], [])
  end

  before(:each) do
    Capistrano::Configuration.reset!
  end

  describe 'committed' do
    before(:each) do
      rake['load:defaults'].invoke
    end

    describe 'check_prerequisites' do
      it 'fails if committed_user is nil' do
        dsl.set :committed_repo, -> { 'test' }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_user is not a String' do
        dsl.set :committed_user, -> { 1 }
        dsl.set :committed_repo, -> { 'test' }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_user is empty' do
        dsl.set :committed_user, -> { '' }
        dsl.set :committed_repo, -> { 'test' }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a ArgumentError
        end
      end

      it 'fails if committed_repo is nil' do
        dsl.set :committed_user, -> { 'test' }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_repo is not a String' do
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { 1 }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_repo is empty' do
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { '' }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a ArgumentError
        end
      end

      it 'fails if committed_github_config is not a Hash' do
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { 'test' }
        dsl.set :committed_github_config, -> { 'test' }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'executes' do
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { 'test' }
        expect(result = subject.invoke).to be_a Array
        expect(result[0]).to be_a Proc
      end
    end

    describe 'check_report_prerequisites' do
      it 'fails if committed_revision_line is not a String' do
        dsl.set :committed_revision_line, -> { nil }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_revision_limit is not an Integer' do
        dsl.set :committed_revision_limit, -> { nil }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_commit_buffer is not an Integer' do
        dsl.set :committed_commit_buffer, -> { nil }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if deprecated committed_output_path is set (is a String)' do
        dsl.set :committed_output_path, -> { 'test' }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_output_text_path is not a String or nil' do
        dsl.set :committed_output_text_path, -> { 1 }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_output_html_path is not a String or nil' do
        dsl.set :committed_output_html_path, -> { 1 }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_issue_match is not a String or Regexp or nil' do
        dsl.set :committed_issue_match, -> { 1 }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if committed_issue_url is not a String or nil' do
        dsl.set :committed_issue_url, -> { 1 }
        begin
          subject.invoke
        rescue StandardError => e
          expect(e).to be_a TypeError
        end
      end

      it 'executes' do
        expect(result = subject.invoke).to be_a Array
        expect(result[0]).to be_a Proc
      end
    end

    describe 'generate' do
      it 'executes' do
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { 'test' }
        expect(result = subject.invoke).to be_a Array
        expect(result[0]).to be_a Proc
      end
    end
  end

  describe 'load' do
    describe 'defaults' do
      it 'sets the defaults' do
        expect(dsl.fetch(:committed_user)).to eq nil
        expect(dsl.fetch(:committed_repo)).to eq nil
        expect(dsl.fetch(:committed_revision_line)).to eq nil
        expect(dsl.fetch(:committed_github_config)).to eq nil
        expect(dsl.fetch(:committed_revision_limit)).to eq nil
        expect(dsl.fetch(:committed_commit_buffer)).to eq nil
        expect(dsl.fetch(:committed_output_text_path)).to eq nil
        expect(dsl.fetch(:committed_output_html_path)).to eq nil
        expect(dsl.fetch(:committed_issue_match)).to eq nil
        expect(dsl.fetch(:committed_issue_postprocess)).to eq nil
        expect(dsl.fetch(:committed_issue_url)).to eq nil
        expect(dsl.fetch(:committed_deployments)).to eq nil
        expect(dsl.fetch(:committed_deployment_id)).to eq nil
        subject.invoke
        expect(dsl.fetch(:committed_user)).to eq nil
        expect(dsl.fetch(:committed_repo)).to eq nil
        expect(dsl.fetch(:committed_revision_line)).to eq t('revision_log_message')
        expect(dsl.fetch(:committed_github_config)).to eq({})
        expect(dsl.fetch(:committed_revision_limit)).to eq 10
        expect(dsl.fetch(:committed_commit_buffer)).to eq 1
        expect(dsl.fetch(:committed_output_text_path)).to eq '%s/public/committed.txt'
        expect(dsl.fetch(:committed_output_html_path)).to eq '%s/public/committed.html'
        expect(dsl.fetch(:committed_issue_match)).to eq '\[\s?([a-zA-Z0-9]+\-[0-9]+)\s?\]'
        expect(dsl.fetch(:committed_issue_postprocess)).to eq []
        expect(dsl.fetch(:committed_issue_url)).to eq 'https://example.jira.com/browse/%s'
        expect(dsl.fetch(:committed_deployments)).to eq false
        expect(dsl.fetch(:committed_deployment_id)).to eq nil
      end
    end
  end
end
