# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ralf/version"

Gem::Specification.new do |s|
  s.name = %q{ralf}
  s.version = Ralf::VERSION

  s.platform           = Gem::Platform::RUBY
  s.authors            = ["Klaas Jan Wierenga", "Leon Berenschot"]
  s.email              = ["k.j.wierenga@gmail.com", "leonb@beriedata.nl"]
  s.homepage           = %q{http://github.com/kjwierenga/ralf}
  s.summary            = %q{Retrieve Amazon Log Files}
  s.description        = %q{ Download logfiles from Amazon S3 buckets to local disk and combine them in one Apache CLF per bucket }

  s.files              = `git ls-files`.split("\n")
  s.test_files         = `git ls-files -- {spec,features}/*`.split("\n")
  s.executables        = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths      = ["lib"]

  s.date               = %q{2013-02-06}
  s.default_executable = %q{ralf}
  s.extra_rdoc_files = [
    "README.rdoc"
  ]

  s.rdoc_options       = ["--exclude", "."]

  s.add_development_dependency "rspec", "~> 2"
  s.add_development_dependency "autotest", '~> 4.4.6'
  s.add_development_dependency "fakeweb", "~> 1.3.0"

  s.add_runtime_dependency "right_aws", "~> 3.0.4"
  s.add_runtime_dependency "logmerge",  "~> 1.0.3"
  s.add_runtime_dependency "chronic",   "~> 0.9.0"

end

