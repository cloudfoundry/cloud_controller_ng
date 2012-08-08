source :rubygems

gem "rake"
gem "bcrypt-ruby"
gem 'eventmachine', :git => 'git://github.com/cloudfoundry/eventmachine.git', :branch => 'release-0.12.11-cf'
gem "rfc822"
gem "sequel"
gem "sinatra"
gem "sinatra-contrib"
gem "yajl-ruby"
gem 'vcap-concurrency', :git => 'git://github.com/cloudfoundry/vcap-concurrency.git'
gem "membrane", "~> 0.0.2"
gem "vcap_common",  "~> 2.0.2", :git => 'git://github.com/cloudfoundry/vcap-common.git', :ref => '6c090f09'
gem "cf-uaa-client", "~> 0.2.0", :git => 'git://github.com/cloudfoundry/uaa', :ref => '792e7816'
gem "httpclient"
gem "steno", "~> 0.0.12"
gem 'stager-client', '~> 0.0.02', :git => 'https://github.com/cloudfoundry/stager-client.git', :ref => '04c2aee9'

group :production do
  gem "pg"
end

group :development do
  gem "sqlite3"
  gem "ruby-graphviz"
end

group :test do
  gem "rspec"
  gem "ci_reporter"
  gem "simplecov"
  gem "simplecov-rcov"
  gem "sqlite3"
  gem "machinist", "~> 1.0.6"
end
