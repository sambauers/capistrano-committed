if ENV['TRAVIS_RUBY_VERSION'] && Gem::Version.new(ENV['TRAVIS_RUBY_VERSION']) > Gem::Version.new('2.2')
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
