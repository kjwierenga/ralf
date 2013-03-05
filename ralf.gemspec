# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ralf/version'

Gem::Specification.new do |gem|
  gem.name          = "ralf"
  gem.version       = Ralf::VERSION
  gem.authors       = ["Leon Berenschot"]
  gem.email         = ["leipeleon@gmail.com"]
  gem.description   = %q{Download and convert S3 logfiles into a CLF file per day}
  gem.summary       = %q{Download and convert S3 logfiles into a CLF file per day}
  gem.homepage      = "https://github.com/kjwierenga/ralf"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "autotest"
  gem.add_development_dependency "fakeweb"

  gem.add_runtime_dependency "right_aws", "~> 1.10.0"
  # gem.add_runtime_dependency "logmerge",  "~> 1.0.3"
  # gem.add_runtime_dependency "chronic",   "~> 0.9.0"

end
