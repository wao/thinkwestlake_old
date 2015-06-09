# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'thinwestlake/version'

Gem::Specification.new do |spec|
  spec.name          = "thinwestlake"
  spec.version       = Thinwestlake::VERSION
  spec.authors       = ["Yang Chen"]
  spec.email         = ["mike.c.yang@gmail.com"]
  spec.summary       = %q{Write a short summary. Required.}
  spec.description   = %q{Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "byebug", "~> 3.5"
  spec.add_development_dependency "minitest", "~> 5"
  spec.add_development_dependency "minitest-reporters", "~> 1"
  spec.add_development_dependency "shoulda-context", "~> 1.2"

  spec.add_runtime_dependency "metaid", "~> 1"
  spec.add_runtime_dependency "builder", "~> 3"
  spec.add_runtime_dependency "main", "> 1"
end
