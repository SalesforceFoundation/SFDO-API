# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'SFDO/API/version'


Gem::Specification.new do |spec|
  spec.name          = "SFDO-API"
  spec.version       = SFDO::API::VERSION
  spec.authors       = ["Chris McMahon", "Kevin Poorman"]
  spec.email         = ["cmcmahon@salesforce.com"]

  spec.summary       = %q{Manipulates records via the Salesforce API using Restforce}
  spec.description   = %q{Primarily used for automated browser tests, this is a convenient way to manipulate generic Salesforce objects across multiple repositories}
  spec.homepage      = "https://github.com/SalesforceFoundation/SFDO-API"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_dependency "pry"
  spec.add_dependency "restforce", "~> 2.1.1"
end
