require 'spec_helper'

context 'rake tasks' do
  let(:rake)      { Rake::Application.new }
  let(:task_name) { format('%s:%s', self.class.superclass.description, self.class.description) }
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
      it 'fails if user is nil' do
        rake['load:defaults'].invoke
        dsl.set :committed_repo, -> { 'test' }
        begin
          subject.invoke
        rescue Exception => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if user is empty' do
        rake['load:defaults'].invoke
        dsl.set :committed_user, -> { '' }
        dsl.set :committed_repo, -> { 'test' }
        begin
          subject.invoke
        rescue Exception => e
          expect(e).to be_a ArgumentError
        end
      end

      it 'fails if repo is nil' do
        rake['load:defaults'].invoke
        dsl.set :committed_user, -> { 'test' }
        begin
          subject.invoke
        rescue Exception => e
          expect(e).to be_a TypeError
        end
      end

      it 'fails if repo is nil' do
        rake['load:defaults'].invoke
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { '' }
        begin
          subject.invoke
        rescue Exception => e
          expect(e).to be_a ArgumentError
        end
      end

      it 'fails if github config is not a hash' do
        rake['load:defaults'].invoke
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { 'test' }
        dsl.set :committed_github_config, -> { 'test' }
        begin
          subject.invoke
        rescue Exception => e
          expect(e).to be_a TypeError
        end
      end

      it 'executes successfully' do
        rake['load:defaults'].invoke
        dsl.set :committed_user, -> { 'test' }
        dsl.set :committed_repo, -> { 'test' }
        result = subject.invoke
        expect(result).to be_a Array
        expect(result[0]).to be_a Proc
      end
    end
  end

  describe 'load' do
    describe 'defaults' do
      it 'sets the defaults' do
        expect(dsl.fetch(:committed_user)).to eq nil
        expect(dsl.fetch(:committed_revision_limit)).to eq nil
        subject.invoke
        expect(dsl.fetch(:committed_user)).to eq nil
        expect(dsl.fetch(:committed_revision_limit)).to eq 10
      end
    end
  end
end
