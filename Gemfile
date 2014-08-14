# This used to be https, but that causes problems in the vagrant container used by warden-jenkins.
source 'http://rubygems.org'

gem 'addressable'
gem 'activesupport', '~> 3.0' # It looks like this is required for DelayedJob, even with the DJ-Sequel extension
gem 'rake'
gem 'bcrypt-ruby'
gem 'eventmachine', '~> 1.0.0'
gem 'fog'
gem 'i18n'
gem 'nokogiri', '~> 1.6.2'
gem 'unf'
gem 'netaddr'
gem 'rfc822'
gem 'sequel'
gem 'sinatra', '~> 1.4'
gem 'sinatra-contrib'
gem 'multi_json'
gem 'yajl-ruby'
gem 'membrane', '~> 1.0'
gem 'httpclient'
gem 'steno'
gem 'cloudfront-signer'
gem 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'
gem 'cf-uaa-lib', '~> 2.1.0', git: 'https://github.com/cloudfoundry/cf-uaa-lib.git', ref: '81e5e4d6'
gem 'cf-message-bus', git: 'https://github.com/cloudfoundry/cf-message-bus.git'
gem 'vcap_common', '~> 4.0'
gem 'cf-registrar', '~> 1.0.1', git: 'https://github.com/cloudfoundry/cf-registrar.git'
gem 'allowy'
gem 'loggregator_emitter', '~> 3.0'
gem 'talentbox-delayed_job_sequel'
gem 'thin', '~> 1.6.0'
gem 'newrelic_rpm'
gem 'clockwork', require: false

group :db do
  gem 'mysql2'
  gem 'pg'
end

group :operations do
  gem 'pry'
end

group :test do
  gem 'codeclimate-test-reporter', require: false
  gem 'debugger'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'machinist', '~> 1.0.6'
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'rspec', '~> 3.0'
  gem 'rspec-instafail'
  gem 'rspec_api_documentation', git: 'https://github.com/zipmark/rspec_api_documentation.git'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rubocop'
  gem 'timecop'
  gem 'webmock'
end

group :development do
  gem 'roodi'
end
