# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ralf/version"

Gem::Specification.new do |s|
  s.name = %q{ralf}
  s.version = Ralf::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Klaas Jan Wierenga", "Leon Berenschot"]
  s.date = %q{2011-05-09}
  s.default_executable = %q{ralf}
  s.description = %q{      Download logfiles from Amazon S3 buckets to local disk and combine them in one Apache CLF per bucket
}
  s.email = ["k.j.wierenga@gmail.com", "leonb@beriedata.nl"]
  s.executables = ["ralf"]
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".rvmrc",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bin/ralf",
    "lib/ralf.rb",
    "lib/ralf/bucket.rb",
    "lib/ralf/config.rb",
    "lib/ralf/interpolation.rb",
    "lib/ralf/log.rb",
    "lib/ralf/option_parser.rb",
    "ralf.gemspec",
    "spec/fixtures/apache.log",
    "spec/fixtures/example_buckets.yaml",
    "spec/ralf/bucket_spec.rb",
    "spec/ralf/config_spec.rb",
    "spec/ralf/interpolation_spec.rb",
    "spec/ralf/log_spec.rb",
    "spec/ralf/option_parser_spec.rb",
    "spec/ralf_spec.rb",
    "spec/spec.opts",
    "spec/spec_helper.rb",
    "spec/support/fakeweb.rb"
  ]
  s.homepage = %q{http://github.com/kjwierenga/ralf}
  s.rdoc_options = ["--exclude", "."]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Retrieve Amazon Log Files}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rspec>, ["~> 1.3.0"])
      s.add_development_dependency(%q<fakeweb>, ["~> 1.2.8"])
      s.add_runtime_dependency(%q<right_aws>, ["~> 1.10.0"])
      s.add_runtime_dependency(%q<logmerge>, ["~> 1.0.2"])
      s.add_runtime_dependency(%q<chronic>, [">= 0.2.3"])
    else
      s.add_dependency(%q<rspec>, ["~> 1.3.0"])
      s.add_dependency(%q<fakeweb>, ["~> 1.2.8"])
      s.add_dependency(%q<right_aws>, ["~> 1.10.0"])
      s.add_dependency(%q<logmerge>, ["~> 1.0.2"])
      s.add_dependency(%q<chronic>, [">= 0.2.3"])
    end
  else
    s.add_dependency(%q<rspec>, ["~> 1.3.0"])
    s.add_dependency(%q<fakeweb>, ["~> 1.2.8"])
    s.add_dependency(%q<right_aws>, ["~> 1.10.0"])
    s.add_dependency(%q<logmerge>, ["~> 1.0.2"])
    s.add_dependency(%q<chronic>, [">= 0.2.3"])
  end
end

