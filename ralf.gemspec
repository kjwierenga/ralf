Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = 'ralf'
  s.version = '0.1.4'
  s.summary = "Retrieve Amazon Log Files"
  s.description = <<-EOF
    Download logfiles from Amazon S3 buckets to local disk and combine them in one Apache CLF per bucket
  EOF

  s.require_path = '.'

  s.test_files = Dir.glob('spec/*_spec.rb')

  s.add_dependency('right_aws', '>= 1.10.0')
  s.add_dependency('logmerge',  '>= 1.0.0')
  s.add_dependency('chronic',  '>= 0.2.3')

  s.rdoc_options << '--exclude' << '.'
  s.has_rdoc = false

  s.authors = ["Klaas Jan Wierenga", "Leon Berenschot"]
  s.homepage = "http://github.com/kjwierenga/ralf"
end
