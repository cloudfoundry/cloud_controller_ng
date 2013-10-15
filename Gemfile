source 'https://rubygems.org'

gem "activesupport", "~> 3.0" # It looks like this is required for DelayedJob, even with the DJ-Sequel extension
gem "rake"
gem "bcrypt-ruby"
gem "eventmachine", "~> 1.0.0"
gem "fog"
gem "rfc822"
gem "sequel", "~> 3.48"
gem "sinatra", "~> 1.4"
gem "sinatra-contrib"
gem "yajl-ruby"
gem "membrane", "~> 0.0.2"
gem "httpclient"
gem "steno"
gem "cloudfront-signer"
gem "vcap-concurrency", :git => "https://github.com/cloudfoundry/vcap-concurrency.git", :ref => "2a5b0179"
gem "cf-uaa-lib", "~> 1.3.7", :git => "https://github.com/cloudfoundry/cf-uaa-lib.git", :ref => "8d34eede"
gem "stager-client", "~> 0.0.02", :git => "https://github.com/cloudfoundry/stager-client.git", :ref => "04c2aee9"
gem "cf-message-bus", :git => "https://github.com/cloudfoundry/cf-message-bus.git"
gem "vcap_common", :git => "https://github.com/cloudfoundry/vcap-common.git"
gem "allowy"
gem "loggregator_emitter", "~> 0.0.15.pre"
gem "talentbox-delayed_job_sequel", "~> 4.0.0.beta1.1"


group :db do
  gem "mysql2"
  gem "pg"
  gem "sqlite3"
end

group :development do
  gem "pry"
end

group :test do
  gem "debugger"
  gem "rspec"
  gem "rspec_api_documentation"
  gem "simplecov"
  gem "simplecov-rcov"
  gem "machinist", "~> 1.0.6"
  gem "webmock"
  gem "guard-rspec"
  gem "timecop"
  gem "rack-test"
  gem "parallel_tests"
  gem "fakefs", :require => "fakefs/safe"
end
