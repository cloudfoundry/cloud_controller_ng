require File.expand_path('lib/steno/version', __dir__)

Gem::Specification.new do |gem|
  gem.authors       = ['mpage']
  gem.email         = ['mpage@rbcon.com']
  gem.description   = 'A thread-safe logging library designed to support multiple log destinations.'
  gem.summary       = 'A logging library.'
  gem.homepage      = 'http://www.cloudfoundry.org'

  gitignore = File.readlines('.gitignore').grep(/^[^#]/).map(&:chomp)

  # Ignore Gemfile, this is a library
  gitignore << 'Gemfile*'

  glob = Dir['**/*']
         .reject { |f| File.directory?(f) }
         .reject { |f| gitignore.any? { |i| File.fnmatch(i, f) } }

  gem.files         = glob
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.name          = 'steno'
  gem.require_paths = ['lib']
  gem.version       = Steno::VERSION

  gem.required_ruby_version = '>= 3.0', '< 4'

  gem.add_dependency('fluent-logger')
  gem.add_dependency('yajl-ruby', '~> 1.0')

  gem.add_development_dependency('rake')
  gem.add_development_dependency('rspec', '~> 3.13.0')
  gem.add_development_dependency('rubocop', '~> 1.60')
  gem.add_development_dependency('rubocop-rake', '~> 0.6')
  gem.add_development_dependency('rubocop-rspec', '~> 3.0')

  gem.add_dependency('syslog') unless RUBY_PLATFORM =~ /mswin|mingw|cygwin/

  if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
    gem.platform = Gem::Platform::CURRENT
    gem.add_dependency('win32-eventlog', '~> 0.6.0')
  end
  gem.metadata['rubygems_mfa_required'] = 'true'
end
