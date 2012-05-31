source :rubygems

gem "rake"
gem "bcrypt-ruby"
gem 'eventmachine', :git => 'git://github.com/cloudfoundry/eventmachine.git', :branch => 'release-0.12.11-cf'
gem "rfc822"
gem "sequel"
gem "sinatra"
gem "sinatra-contrib"
gem "yajl-ruby"
gem 'vcap_common', :require => ['vcap/common', 'vcap/component'], :git => 'git://github.com/cloudfoundry/vcap-common.git', :ref => '16c06d7f'
gem 'vcap_logging', :require => ['vcap/logging'], :git => 'git://github.com/cloudfoundry/common.git', :ref => 'e36886a1'
gem "cf-uaa-client", "~> 0.2.0", :git => 'git://github.com/cloudfoundry/uaa.git', :ref => '39d045db'
gem "httpclient"

group :production do
  gem "pg"
end

group :development do
  gem "sqlite3"
  gem "ruby-graphviz"
end

group :test do
  gem "rspec"
  gem "simplecov"
  gem "sqlite3"
  gem "machinist", "~> 1.0.6"
end
