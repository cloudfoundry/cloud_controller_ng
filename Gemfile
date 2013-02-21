source 'https://rubygems.org'

gem "rake"
gem "bcrypt-ruby"
gem 'eventmachine', "~> 1.0.0"
gem 'fog'
gem "mysql2"
gem "redis"
gem "rfc822"
gem "sequel"
gem "sinatra"
gem "sinatra-contrib"
gem "yajl-ruby"
gem 'vcap-concurrency', :git => 'git://github.com/cloudfoundry/vcap-concurrency.git'
gem "membrane", "~> 0.0.2"
gem "vcap_common",  "~> 2.0.8", :git => 'git://github.com/cloudfoundry/vcap-common.git', :ref => '68d86f57fb'
gem "cf-uaa-lib", "~> 1.3.7", :git => 'git://github.com/cloudfoundry/cf-uaa-lib.git', :ref =>  '8d34eede58'
gem "httpclient"
gem "steno", "~> 1.0.0"
gem 'stager-client', '~> 0.0.02', :git => 'https://github.com/cloudfoundry/stager-client.git', :ref => '04c2aee9'

# These are outside the test group in order to run rake tasks
gem "rspec"
gem "ci_reporter"

group :production do
  gem "pg"
end

group :development do
  gem "sqlite3"
  gem "ruby-graphviz"
end

group :test do
  gem "simplecov"
  gem "simplecov-rcov"
  gem "sqlite3"
  gem "machinist", "~> 1.0.6"
  gem "webmock"
  gem "guard-rspec"
  gem "timecop"
  gem "mock_redis"
end
