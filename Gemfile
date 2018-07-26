source 'https://rubygems.org'

gem 'addressable'
gem 'allowy'
gem 'cf-copilot'
gem 'clockwork', require: false
gem 'cloudfront-signer'
gem 'em-http-request', '~> 1.1'
gem 'eventmachine', '~> 1.0.9'
gem 'httpclient'
gem 'i18n'
gem 'json-schema'
gem 'json_pure'
gem 'loggregator_emitter', '~> 5.0'
gem 'membrane', '~> 1.0'
gem 'mime-types', '~> 3.0'
gem 'multi_json'
gem 'multipart-parser'
gem 'net-ssh'
gem 'netaddr'
gem 'newrelic_rpm'
gem 'nokogiri', '~> 1.8.1'
gem 'palm_civet'
gem 'posix-spawn', '~> 0.3.6'
gem 'protobuf', '3.6.12'
gem 'public_suffix'
gem 'rake'
gem 'rfc822'
gem 'rubyzip', git: 'https://github.com/rubyzip/rubyzip.git', ref: '8887b70'

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

# Rails Components
gem 'actionpack', '~> 4.2'
gem 'actionview', '~> 4.2'
gem 'activemodel', '~> 4.2'
gem 'railties', '~> 4.2'

# Blobstore and Bits Service Dependencies
gem 'azure-storage', '0.14.0.preview' # https://github.com/Azure/azure-storage-ruby/issues/122
gem 'bits_service_client', '~> 3.0'
gem 'fog-aliyun'
gem 'fog-aws'
gem 'fog-azure-rm'
gem 'fog-google'
gem 'fog-local'
gem 'fog-openstack'

gem 'cf-uaa-lib', '~> 3.14.0'
gem 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'

gem 'cf-perm', '~> 0.0.10'
gem 'scientist'

group :db do
  gem 'mysql2', '~> 0.4.10'
  gem 'pg'
end

group :operations do
  gem 'awesome_print'
  gem 'pry-byebug'
end

group :test do
  gem 'cf-perm-test-helpers', '~> 0.0.6'
  gem 'codeclimate-test-reporter', require: false
  gem 'hashdiff'
  gem 'machinist', '~> 1.0.6'
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'rspec'
  gem 'rspec-collection_matchers'
  gem 'rspec-instafail'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rspec-wait'
  gem 'rspec_api_documentation'
  gem 'rubocop', '~> 0.51.0'
  gem 'timecop'
  gem 'webmock', '> 2.3.1'
end

group :development do
  gem 'byebug'
  gem 'debase', '>= 0.2.2.beta14'
  gem 'listen'
  gem 'roodi'
  gem 'ruby-debug-ide', '>= 0.7.0.beta4'
  gem 'spork', git: 'https://github.com/sporkrb/spork', ref: '224df49' # '~> 1.0rc'
end
