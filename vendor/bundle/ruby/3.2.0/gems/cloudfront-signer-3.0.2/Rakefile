require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
  t.rspec_opts = ['--colour', '--format', 'nested']
end

task default: :spec

require 'rdoc/task'

Rake::RDocTask.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_files.include %w(README.md LICENSE lib/cloudfront-signer.rb)
  rdoc.rdoc_dir = 'doc'
  rdoc.options << '--line-numbers'
  rdoc.options << '--coverage-report'
  rdoc.markup = 'markdown'
end
