# coding: utf-8
$:.push File.expand_path("../lib", __FILE__)

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

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.5"
  spec.add_development_dependency 'simplecov', '~> 0.12'
  spec.add_development_dependency 'codecov', '~> 0.1.9'
  spec.add_development_dependency 'sidekiq', '~> 5.2'

  spec.required_ruby_version = '>= 2.3'

  spec.add_dependency 'wamp_client', '~> 0.2.2'
  spec.add_dependency 'redis', '~> 4.0'
end
