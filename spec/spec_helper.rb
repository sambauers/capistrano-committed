def is_latest_ruby?(version)
  return false if version.nil?
  return false if version.empty?
  return false if !(Gem::Version.correct? version)
  Gem::Version.new(version) >= Gem::Version.new('2.2')
end

if is_latest_ruby?(ENV['TRAVIS_RUBY_VERSION'])
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
end

require 'webmock/rspec'
WebMock.disable_net_connect!(:allow => "codeclimate.com")

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../lib/committed', __FILE__)
require 'i18n'
require 'capistrano/all'

def t(key, options={})
  I18n.t(key, options.merge(scope: :capistrano))
end

require 'capistrano/committed'

ENV['TZ'] = 'UTC'

RSpec.configure do |config|
  config.include WebMock::API

  config.before(:each) do
    WebMock.reset!
  end
  config.after(:each) do
    WebMock.reset!
  end
end

def fixture_path
  File.expand_path('../fixtures', __FILE__)
end

def fixture(file)
  File.new(File.join(fixture_path, '/', file))
end

def tasks_path
  File.expand_path('../../lib/capistrano/tasks', __FILE__)
end
