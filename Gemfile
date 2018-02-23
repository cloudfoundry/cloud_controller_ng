source 'https://rubygems.org'

gem 'actionpack'
gem 'actionview'
gem 'activemodel'
gem 'addressable'
gem 'allowy'
gem 'clockwork', require: false
gem 'cloudfront-signer'
gem 'em-http-request', '~> 1.0'
gem 'eventmachine', '~> 1.0.9'
gem 'httpclient'
gem 'i18n'
gem 'json-schema'
gem 'json_pure', '1.8.6'
gem 'loggregator_emitter', '~> 5.0'
gem 'membrane', '~> 1.0'
gem 'mime-types', '~> 3.0'
gem 'multi_json'
gem 'multipart-parser'
gem 'net-ssh'
gem 'netaddr'
gem 'newrelic_rpm', '>= 3.12'
gem 'nokogiri', '~> 1.8.1'
gem 'palm_civet'
gem 'posix-spawn', '~> 0.3.6'
gem 'protobuf', '3.6.12'
gem 'public_suffix'
gem 'railties'
gem 'rake'
gem 'rfc822'
gem 'rubyzip'
gem 'sequel'
gem 'sinatra', '~> 1.4'
gem 'sinatra-contrib'
gem 'statsd-ruby', '~> 1.4.0'
gem 'steno'
gem 'talentbox-delayed_job_sequel', '~> 4.2.2'
gem 'thin'
gem 'unf'
gem 'vmstat', '~> 2.0'
gem 'yajl-ruby'

gem 'fog-aws'
gem 'fog-azure-rm'
gem 'fog-google'
gem 'fog-local'
gem 'fog-openstack'

gem 'bits_service_client'
gem 'cf-uaa-lib', '~> 3.13.0'
gem 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'

gem 'cf-perm', git: 'https://github.com/cloudfoundry-incubator/perm-rb.git', branch: 'master'
gem 'scientist'

group :db do
  gem 'mysql2', '0.4.8'
  gem 'pg', '0.19.0'
end

group :operations do
  gem 'awesome_print'
  gem 'pry-byebug'
end

group :test do
  gem 'cf-perm-test-helpers', git: 'https://github.com/cloudfoundry-incubator/perm-rb.git', branch: 'master'
  gem 'codeclimate-test-reporter', require: false
  gem 'fakefs', require: 'fakefs/safe'
  gem 'hashdiff'
  gem 'machinist', '~> 1.0.6'
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'rspec', '~> 3.0'
  gem 'rspec-collection_matchers'
  gem 'rspec-instafail'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rspec_api_documentation', git: 'https://github.com/zipmark/rspec_api_documentation.git'
  gem 'rubocop'
  gem 'timecop'
  gem 'webmock', '> 2.3.1'
end

group :development do
  gem 'byebug'
  gem 'debase', '>= 0.2.2.beta14'
  gem 'roodi'
  gem 'ruby-debug-ide', '>= 0.6.1.beta4'
end
