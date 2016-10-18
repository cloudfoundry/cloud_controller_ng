source 'https://rubygems.org'

gem 'addressable'
gem 'railties'
gem 'rake'

gem 'eventmachine'

# Note: We had to overwrite the Gemfile.lock to use this specific version of fog-google
# that has not been updated in the fog gem. See https://www.pivotaltracker.com/story/show/128669549 for more info
gem 'fog-google', '~> 0.4.0'
gem 'google-api-client', '~> 0.8.6'

gem 'fog'
gem 'i18n'
gem 'nokogiri', '~> 1.6.8'
gem 'unf'
gem 'netaddr'
gem 'rfc822'
gem 'sequel'
gem 'sinatra', '~> 1.4'
gem 'sinatra-contrib'
gem 'multi_json'
gem 'yajl-ruby'
gem 'mime-types', '~> 2.6.2'
gem 'membrane', '~> 1.0'
gem 'httpclient'
gem 'steno'
gem 'cloudfront-signer'
gem 'vcap_common', '~> 4.0.4'
gem 'allowy'
gem 'loggregator_emitter', '~> 5.0'
gem 'delayed_job_sequel', git: 'https://github.com/cloudfoundry/delayed_job_sequel.git'
gem 'thin'
gem 'newrelic_rpm', '>= 3.12'
gem 'clockwork', require: false
gem 'statsd-ruby'
gem 'activemodel'
gem 'actionpack'
gem 'actionview'
gem 'public_suffix'

gem 'nats'

# We need to use https for git urls as the git protocol is blocked by various
# firewalls
gem 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'
gem 'cf-uaa-lib', git: 'https://github.com/cloudfoundry/cf-uaa-lib.git', ref: 'db8fe11b56a1d008131a7d757b49c8a00242b9ab'
gem 'cf-message-bus', '~> 0.3.0'
gem 'bits_service_client', github: 'cloudfoundry-incubator/bits-service-client'

group :db do
  gem 'mysql2', '0.4.4'
  gem 'pg', '0.19.0'
end

group :operations do
  gem 'pry-byebug'
  gem 'awesome_print'
end

group :test do
  gem 'codeclimate-test-reporter', require: false
  gem 'fakefs', require: 'fakefs/safe'
  gem 'machinist', '~> 1.0.6'
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'rspec', '~> 3.0'
  gem 'rspec-instafail'
  gem 'rspec_api_documentation', git: 'https://github.com/zipmark/rspec_api_documentation.git'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rspec-rails'
  gem 'rubocop'
  gem 'timecop'
  gem 'webmock'
end

group :development do
  gem 'roodi'
  gem 'ruby-debug-ide'
  gem 'byebug'
end
