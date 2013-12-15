# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'perpetuity/mongodb/version'

Gem::Specification.new do |spec|
  spec.name          = "perpetuity-mongodb"
  spec.version       = Perpetuity::Mongodb::VERSION
  spec.authors       = ["Jamie Gaskins"]
  spec.email         = ["jgaskins@gmail.com"]
  spec.description   = %q{MongoDB adapter for Perpetuity}
  spec.summary       = %q{MongoDB adapter for Perpetuity}
  spec.homepage      = "https://github.com/jgaskins/perpetuity-mongodb"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency "perpetuity", "~> 1.0.0.beta"
  spec.add_runtime_dependency "moped"
end
