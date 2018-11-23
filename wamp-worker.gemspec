# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wamp/worker/version'

Gem::Specification.new do |spec|
  spec.name          = "wamp-worker"
  spec.version       = Wamp::Worker::VERSION
  spec.authors       = ["Eric Chapman"]
  spec.email         = ["eric.chappy@gmail.com"]

  spec.summary       = %q{Web Application Messaging Protocol Client worker for Rails}
  spec.homepage      = "https://github.com/ericchapman/ruby_wamp_worker"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'codecov'

  spec.add_dependency 'wamp_client', '~> 0.1.1'
  spec.add_dependency 'redis'
  spec.add_dependency 'sidekiq'
end
