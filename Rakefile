require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings

    gem.name = "ralf"
    gem.summary = "Retrieve Amazon Log Files"
    gem.description = <<-EOF
      Download logfiles from Amazon S3 buckets to local disk and combine them in one Apache CLF per bucket
    EOF
    gem.email = [ "k.j.wierenga@gmail.com", "leonb@beriedata.nl" ]
    gem.homepage = "http://github.com/kjwierenga/ralf"
    gem.authors = ["Klaas Jan Wierenga", "Leon Berenschot"]

    gem.add_development_dependency 'rspec',   '~> 1.3.0'
    gem.add_development_dependency 'fakeweb', '~> 1.2.8'

    gem.add_dependency 'right_aws', '~> 1.10.0'
    gem.add_dependency 'logmerge',  '~> 1.0.2'
    gem.add_dependency 'chronic',   '>= 0.2.3'

    gem.rdoc_options << '--exclude' << '.'
    gem.has_rdoc = false
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Warning: Jeweler (or a dependency) not available."
  puts "         Check dependencies with `rake check_dependencies`."
end

begin
  require 'spec/rake/spectask'
  Spec::Rake::SpecTask.new(:spec) do |spec|
    spec.libs << 'lib' << 'spec'
    spec.spec_files = FileList['spec/**/*_spec.rb']
  end

  Spec::Rake::SpecTask.new(:rcov) do |spec|
    spec.libs << 'lib' << 'spec'
    spec.pattern = 'spec/**/*_spec.rb'
    spec.rcov = true
  end

  task :spec => :check_dependencies

  task :default => :spec
rescue LoadError
  puts "Warning: Rspec not available."
  puts "         Check dependencies with `rake check_dependencies`."
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ralf #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
