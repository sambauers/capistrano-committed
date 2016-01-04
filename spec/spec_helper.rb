require "codeclimate-test-reporter"
CodeClimate::TestReporter.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../lib/committed', __FILE__)
require 'i18n'
require 'capistrano/all'

def t(key, options={})
  I18n.t(key, options.merge(scope: :capistrano))
end

require 'capistrano/committed'
