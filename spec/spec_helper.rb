def latest_ruby?(version)
  return false if version.nil?
  return false if version.empty?
  return false unless Gem::Version.correct?(version)
  Gem::Version.new(version) >= Gem::Version.new('2.5')
end

if latest_ruby?(ENV['TRAVIS_RUBY_VERSION'])
  require 'simplecov'
  SimpleCov.start
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift File.expand_path('../lib/committed', __dir__)
require 'i18n'
require 'capistrano/all'

def t(key, options = {})
  I18n.t(key, options.merge(scope: :capistrano))
end

require 'capistrano/committed'

ENV['TZ'] = 'UTC'

def tasks_path
  File.expand_path('../lib/capistrano/tasks', __dir__)
end
