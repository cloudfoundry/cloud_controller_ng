# Copyright (c) 2009-2012 VMware, Inc.
$:.unshift(File.expand_path("../../lib", __FILE__))

require "rubygems"
require "bundler"
require "bundler/setup"

require "machinist/sequel"
require "rack/test"

require "cloud_controller"

def spec_dir
  File.expand_path("..", __FILE__)
end

def artifacts_dir
  File.join(spec_dir, "artifacts")
end

def artifact_filename(name)
  File.join(artifacts_dir, name)
end

def log_filename
  artifact_filename("spec.log")
end

def validate_version_string(min_version, version)
  min_fields = min_version.split(".").map { |v| v.to_i }
  ver_fields = version.split(".").map { |v| v.to_i }

  (0..2).each do |i|
    return true  if ver_fields[i] > min_fields[i]
    return false if ver_fields[i] < min_fields[i]
  end

  return true
end

def validate_sqlite_version(db)
  min_version = "3.6.19"
  version = db.fetch("SELECT sqlite_version()").first[:"sqlite_version()"]
  unless validate_version_string(min_version, version)
    puts <<EOF
The CC models require sqlite version >= #{min_version} but you are
running #{version} On OSX, you will might to install the sqlite
gem against an upgraded sqlite (from source, homebrew, macports, etc)
and not the system sqlite. You can do so with a cummand
such as:

  gem install sqlite3 -- --with-sqlite3-include=/usr/local/include/ \
                         --with-sqlite3-lib=/usr/local/lib

EOF
    exit 1
  end
end

FileUtils.mkdir_p artifacts_dir
File.unlink(log_filename) if File.exists?(log_filename)
VCAP::Logging.setup_from_config(:level => "debug2", :file => log_filename)
db = VCAP::CloudController::DB.connect(VCAP::Logging.logger("cc.db"),
                                       :database  => "sqlite:///",
                                       :log_level => "debug2")
validate_sqlite_version(db)
VCAP::CloudController::DB.apply_migrations(db)

def reset_database(db)
  db.execute("PRAGMA foreign_keys = OFF")
  db.tables.each do |table|
    db.drop_table(table)
  end

  db.execute("PRAGMA foreign_keys = ON")
  VCAP::CloudController::DB.apply_migrations(db)
end

RSpec.configure do |rspec_config|
  rspec_config.include VCAP::CloudController
  rspec_config.include Rack::Test::Methods

  rspec_config.before(:each) do |example|
    reset_database db
  end
end

RSpec::Matchers.define :be_recent do |expected|
  match do |actual|
    actual.should be_within(2).of(Time.now)
  end
end

shared_examples "a vcap rest error response" do |description_match|
  let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

  it "should contain a numeric 'code'" do
    decoded_response['code'].should_not be_nil
    decoded_response['code'].should be_a_kind_of(Fixnum)
  end

  it "should contain a 'description'" do
    decoded_response['description'].should_not be_nil
    decoded_response['description'].should be_a_kind_of(String)
  end

  if description_match
    it "should contain a 'description' that matches #{description_match}" do
      decoded_response['description'].should match /#{description_match}/
    end
  end
end

require "cloud_controller/models"
require "blueprints"
