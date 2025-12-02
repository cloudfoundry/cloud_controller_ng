$:.unshift(File.dirname(__FILE__) + "/../lib")
ENV["RAILS_ENV"] = "test"

require "rubygems"
require "bundler/setup"
require "rspec"
require "logger"
require "sequel"

def jruby?
  (defined?(RUBY_ENGINE) && RUBY_ENGINE=="jruby") || defined?(JRUBY_VERSION)
end

DB = case ENV["DB"]
when "mysql"
  begin
    if jruby?
      Sequel.connect "jdbc:mysql://localhost/delayed_jobs", test: true
    else
      Sequel.connect adapter: "mysql2", database: "delayed_jobs", test: true
    end
  rescue Sequel::DatabaseConnectionError
    system "mysql -e 'CREATE DATABASE IF NOT EXISTS `delayed_jobs` DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci'"
    retry
  end
when "postgres"
  begin
    if jruby?
      Sequel.connect "jdbc:postgresql://localhost/delayed_jobs", test: true
    else
      Sequel.connect adapter: "postgres", database: "delayed_jobs", test: true
    end
  rescue Sequel::DatabaseConnectionError
    system "createdb --encoding=UTF8 delayed_jobs"
    retry
  end
else
  if jruby?
    Sequel.connect "jdbc:sqlite::memory:", test: true
  else
    Sequel.sqlite
  end
end

DB.drop_table :delayed_jobs rescue Sequel::DatabaseError
DB.drop_table :stories rescue Sequel::DatabaseError

DB.create_table :delayed_jobs do
  primary_key :id
  Integer :priority, :default => 0
  Integer :attempts, :default => 0
  String  :handler, :text => true
  String  :last_error, :text => true
  Time    :run_at
  Time    :locked_at
  Time    :failed_at
  String  :locked_by
  String  :queue
  Time    :created_at
  Time    :updated_at
  index   [:priority, :run_at]
end
DB.create_table :stories do
  primary_key :story_id
  String      :text
  TrueClass   :scoped, :default => true
end

require "delayed_job_sequel"
require "delayed/backend/shared_spec"

Delayed::Worker.logger = Logger.new(ENV["DEBUG"] ? $stdout : "/tmp/dj.log")
DB.logger = Delayed::Worker.logger

Delayed::Worker.backend = :sequel

# Purely useful for test cases...
class Story < Sequel::Model
  def tell; text; end
  def whatever(n, _); tell*n; end
  def update_attributes(*args)
    update *args
  end
  handle_asynchronously :whatever
  alias_method :persisted?, :exists?
end
