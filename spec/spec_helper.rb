# Copyright (c) 2009-2012 VMware, Inc.
$:.unshift(File.expand_path("../../lib", __FILE__))

require "rubygems"
require "bundler"
require "bundler/setup"

require "machinist/sequel"
require "rack/test"

require "steno"
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

FileUtils.mkdir_p artifacts_dir
File.unlink(log_filename) if File.exists?(log_filename)
Steno.init(Steno::Config.new(:default_log_level => "debug",
                             :sinks => [Steno::Sink::IO.for_file(log_filename)]))
db_logger = Steno.logger("cc.db")
if ENV["DB_LOG_LEVEL"]
  level = ENV["DB_LOG_LEVEL"].downcase.to_sym
  db_logger.level = level if Steno::Logger::LEVELS.include? level
end
db = VCAP::CloudController::DB.connect(db_logger,
                                       :database  => "sqlite:///",
                                       :log_level => "debug2")
VCAP::CloudController::DB.apply_migrations(db)

def reset_database(db)
  db.execute("PRAGMA foreign_keys = OFF")
  db.tables.each do |table|
    db.drop_table(table)
  end

  db.execute("PRAGMA foreign_keys = ON")
  VCAP::CloudController::DB.apply_migrations(db)
end

module VCAP::CloudController::SpecHelper
  def config_override(hash)
    @config_override = hash
  end

  def config
    config_file = File.expand_path("../../config/cloud_controller.yml", __FILE__)
    c = VCAP::CloudController::Config.from_file(config_file)
    c = c.merge(@config_override || {})
    VCAP::CloudController::Config.configure(c)
    c
  end

  def configure
    config
  end

  def create_zip(zip_name, file_count, file_size=1024)
    total_size = file_count * file_size
    files = []
    file_count.times do |i|
      tf = Tempfile.new("ziptest_#{i}")
      files << tf
      tf.write("A" * file_size)
      tf.close
    end
    child = POSIX::Spawn::Child.new("zip", zip_name, *files.map(&:path))
    child.status.exitstatus.should == 0
    total_size
  end

  def with_em_and_thread(opts = {}, &blk)
    auto_stop = opts.has_key?(:auto_stop) ? opts[:auto_stop] : true
    Thread.abort_on_exception = true
    EM.run do
      EM.reactor_thread?.should == true
      Thread.new do
        EM.reactor_thread?.should == false
        blk.call
        EM.reactor_thread?.should == false
        if auto_stop
          EM.next_tick { EM.stop }
        end
      end
      EM.reactor_thread?.should == true
    end
  end

  RSpec::Matchers.define :be_recent do |expected|
    match do |actual|
      actual.should be_within(2).of(Time.now)
    end
  end

  # @param [Hash] expecteds key-value pairs of messages and responses
  # @return [#==]
  RSpec::Matchers.define(:respond_with) do |expecteds|
    match do |actual|
      expecteds.all? do |message, matcher|
        if matcher.respond_to?(:matches?)
          matcher.matches?(actual.public_send(message))
        else
          matcher == actual.public_send(message)
        end
      end
    end
  end

  RSpec::Matchers.define :json_match do |matcher|
    # RSpect matcher?
    if matcher.respond_to?(:matches?)
      match do |json|
        actual = Yajl::Parser.parse(json)
        matcher.matches?(actual)
      end
    # regular values or RSpec Mocks argument matchers
    else
      match do |json|
        actual = Yajl::Parser.parse(json)
        matcher == actual
      end
    end
  end

  shared_examples "a vcap rest error response" do |description_match|
    let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

    it "should contain a numeric code" do
      decoded_response["code"].should_not be_nil
      decoded_response["code"].should be_a_kind_of(Fixnum)
    end

    it "should contain a description" do
      decoded_response["description"].should_not be_nil
      decoded_response["description"].should be_a_kind_of(String)
    end

    if description_match
      it "should contain a description that matches #{description_match}" do
        decoded_response["description"].should match /#{description_match}/
      end
    end
  end
end

RSpec.configure do |rspec_config|
  rspec_config.include VCAP::CloudController
  rspec_config.include Rack::Test::Methods
  rspec_config.include VCAP::CloudController::SpecHelper

  rspec_config.before(:each) do |example|
    VCAP::CloudController::SecurityContext.current_user = nil
    reset_database db
  end
end


require "cloud_controller/models"
require "blueprints"

require "models/spec_helper.rb"
