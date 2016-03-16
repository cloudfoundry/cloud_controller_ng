# This used to be https, but that causes problems in the vagrant container used by warden-jenkins.
source 'http://rubygems.org'

gem 'addressable'
gem 'railties', '~>4.2.5.2'
gem 'rake'
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
gem 'mime-types', '~> 2.6.2'
gem 'membrane', '~> 1.0'
gem 'httpclient'
gem 'steno'
gem 'cloudfront-signer'
gem 'vcap_common', '~> 4.0.3'
gem 'allowy'
gem 'loggregator_emitter', '~> 5.0'
gem 'delayed_job_sequel', git: 'https://github.com/cloudfoundry/delayed_job_sequel.git'
gem 'thin', '~> 1.6.0'
gem 'newrelic_rpm', '3.12.0.288'
gem 'clockwork', require: false
gem 'statsd-ruby'
gem 'activemodel', '~> 4.2.5.2'
gem 'actionpack', '~> 4.2.5.2'
gem 'actionview', '~> 4.2.5.2'
gem 'public_suffix'

# Requiring this particular commit to get a fix to a race condition when subscribing before a connection is made.
# (see https://github.com/nats-io/ruby-nats/commit/3f3efc6bc41cc483f2d90cb9d401ba4aa3e727d3)
# If a release newer than 0.5.1 is made that includes this commit, we may wish to switch to that.
gem 'nats', git: 'https://github.com/nats-io/ruby-nats', ref: '8571cf9d685b6063002486614b66a28bad254a64'

# We need to use https for git urls as the git protocol is blocked by various
# firewalls
gem 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'
gem 'cf-uaa-lib', '~> 3.1.0', git: 'https://github.com/cloudfoundry/cf-uaa-lib.git', ref: 'b1e11235dc6cd7d8d4680e005526de37201305ea'
gem 'cf-message-bus', '~> 0.3.0'

group :db do
  gem 'mysql2', '0.3.20'
  gem 'pg', '0.16.0'
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
