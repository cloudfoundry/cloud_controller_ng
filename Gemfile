source 'https://rubygems.org'

gem "rake"
gem "bcrypt-ruby"
gem "eventmachine", "~> 1.0.0"
gem "fog"
gem "rfc822"
gem "sequel"
gem "sinatra"
gem "sinatra-contrib"
gem "yajl-ruby"
gem "vcap-concurrency", :git => "https://github.com/cloudfoundry/vcap-concurrency.git", :ref => "2a5b0179"
gem "membrane", "~> 0.0.2"
gem "vcap_common",  "~> 2.0.8", :git => "https://github.com/cloudfoundry/vcap-common.git"
gem "cf-uaa-lib", "~> 1.3.7", :git => "https://github.com/cloudfoundry/cf-uaa-lib.git", :ref =>  "8d34eede"
gem "httpclient"
gem "steno", "~> 1.0.0"
gem "stager-client", "~> 0.0.02", :git => "https://github.com/cloudfoundry/stager-client.git", :ref => "04c2aee9"

# These are outside the test group in order to run rake tasks
gem "rspec"
gem "ci_reporter"

group :db do
  gem "mysql2"
  gem "pg"
  gem "sqlite3"
  gem "ruby-oci8" if ENV['DB'] == 'oracle'
end

group :development do
  gem "ruby-graphviz"
end

group :test do
  gem "simplecov"
  gem "simplecov-rcov"
  gem "machinist", "~> 1.0.6"
  gem "webmock"
  gem "guard-rspec"
  gem "timecop"
  gem "debugger"
end
