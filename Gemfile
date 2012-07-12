source :rubygems

gem "rake"
gem "bcrypt-ruby"
gem "eventmachine", "~> 0.12.11.cloudfoundry.3"
gem "rfc822"
gem "sequel"
gem "sinatra"
gem "sinatra-contrib"
gem "yajl-ruby"
gem 'vcap-concurrency'
gem "membrane"
gem "vcap_common", "~> 2.0.0"
gem "vcap_logging"
gem "cf-uaa-client", "~> 0.2.0"
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
  gem "ci_reporter"
  gem "simplecov"
  gem "simplecov-rcov"
  gem "sqlite3"
  gem "machinist", "~> 1.0.6"
end
