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

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../lib/committed', __FILE__)
require 'i18n'
require 'capistrano/all'

def t(key, options={})
  I18n.t(key, options.merge(scope: :capistrano))
end

require 'capistrano/committed'
