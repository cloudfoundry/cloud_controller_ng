source 'https://rubygems.org'

gem 'actionpack'
gem 'actionview'
gem 'activemodel'
gem 'addressable'
gem 'allowy'
gem 'clockwork', require: false
gem 'cloudfront-signer'
gem 'delayed_job_sequel', git: 'https://github.com/cloudfoundry/delayed_job_sequel.git'
gem 'eventmachine', '~> 1.0.9'
gem 'google-api-client', '~> 0.8.6' # required for fog-google
gem 'httpclient'
gem 'i18n'
gem 'json-schema'
gem 'loggregator_emitter', '~> 5.0'
gem 'membrane', '~> 1.0'
gem 'mime-types', '~> 2.6.2'
gem 'multi_json'
gem 'net-ssh'
gem 'netaddr'
gem 'newrelic_rpm', '>= 3.12'
gem 'nokogiri', '~> 1.7.2'
gem 'protobuf'
gem 'public_suffix', '~> 1.0'
gem 'railties'
gem 'rake'
gem 'rfc822'
gem 'rubyzip'
gem 'sequel'
gem 'sinatra', '~> 1.4'
gem 'sinatra-contrib'
gem 'statsd-ruby', '~> 1.4.0'
gem 'steno'
gem 'thin'
gem 'unf'
gem 'vcap_common', '~> 4.0.4'
gem 'yajl-ruby'

gem 'fog-aws'
gem 'fog-azure-rm'
gem 'fog-google'
gem 'fog-local'
gem 'fog-openstack'

gem 'bits_service_client'
gem 'cf-uaa-lib', '~> 3.11.0'
gem 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'

group :db do
  gem 'mysql2', '0.4.8'
  gem 'pg', '0.19.0'
end

group :operations do
  gem 'awesome_print'
  gem 'pry-byebug'
end

group :test do
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
  gem 'webmock'
end

group :development do
  gem 'byebug'
  gem 'debase', '>= 0.2.2.beta10'
  gem 'roodi'
  gem 'ruby-debug-ide', '>= 0.6.1.beta4'
end
