# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/committed/version'

Gem::Specification.new do |spec|
  spec.name          = "capistrano-committed"
  spec.version       = Capistrano::Committed::VERSION
  spec.authors       = ["Sam Bauers"]
  spec.email         = ["sam@wopr.com.au"]
  spec.license       = 'MIT'

  spec.summary       = %q{Tells you what Capistrano 3 is going to deploy based on GitHub commits since the last release.}
  spec.description   = %q{Tells you what Capistrano 3 is going to deploy based on GitHub commits since the last release.}
  spec.homepage      = "https://github.com/sambauers/capistrano-committed"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", "~> 2.0"
  spec.add_dependency "capistrano", "~> 3.8"
  spec.add_dependency "github_api", "~> 0.17"
  spec.add_dependency "mustache", "~> 1.0"

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 11.0"
  spec.add_development_dependency "rspec", "~> 3.6"
end
