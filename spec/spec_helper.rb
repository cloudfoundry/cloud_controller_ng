$:.unshift(File.expand_path("../../lib", __FILE__))
$:.unshift(File.expand_path("../../app", __FILE__))

require "rubygems"
require "bundler"
require "bundler/setup"

require "fakefs/safe"
require "machinist/sequel"
require "machinist/object"
require "rack/test"
require "timecop"

require "steno"
require "webmock/rspec"
require "cf_message_bus/mock_message_bus"

require "cloud_controller"
require "allowy/rspec"

require "pry"
require "posix/spawn"

require "rspec_api_documentation"

require "services"

module VCAP::CloudController
  MAX_LOG_FILE_SIZE_IN_BYTES = 100_000_000
  class SpecEnvironment
    def initialize
      ENV["CC_TEST"] = "true"
      FileUtils.mkdir_p(artifacts_dir)

      if File.exist?(log_filename) && File.size(log_filename) > MAX_LOG_FILE_SIZE_IN_BYTES
        FileUtils.rm_f(log_filename)
      end

      StenoConfigurer.new(level: "debug2").configure do |steno_config_hash|
        steno_config_hash[:sinks] = [Steno::Sink::IO.for_file(log_filename)]
      end

      reset_database
      VCAP::CloudController::DB.load_models(config.fetch(:db), db_logger)
      VCAP::CloudController::Config.run_initializers(config)

      VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
    end

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

    def reset_database
      prepare_database

      db.tables.each do |table|
        drop_table_unsafely(table)
      end

      DBMigrator.new(db).apply_migrations
    end

    def reset_database_with_seeds
      reset_database
      VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
    end

    def db_connection_string
      if ENV["DB_CONNECTION"]
        "#{ENV["DB_CONNECTION"]}/cc_test_#{ENV["TEST_ENV_NUMBER"]}"
      else
        "sqlite:///tmp/cc_test#{ENV["TEST_ENV_NUMBER"]}.db"
      end
    end

    def db
      Thread.current[:db] ||= VCAP::CloudController::DB.connect(config.fetch(:db), db_logger)
    end

    def db_logger
      return @db_logger if @db_logger
      @db_logger = Steno.logger("cc.db")
      if ENV["DB_LOG_LEVEL"]
        level = ENV["DB_LOG_LEVEL"].downcase.to_sym
        @db_logger.level = level if Steno::Logger::LEVELS.include? level
      end
      @db_logger
    end

    def config
      config_file = File.expand_path("../../config/cloud_controller.yml", __FILE__)
      config_hash = VCAP::CloudController::Config.from_file(config_file)

      config_hash.update(
        :nginx => {:use_nginx => true},
        :resource_pool => {
          :resource_directory_key => "spec-cc-resources",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          },
        },
        :packages => {
          :app_package_directory_key => "cc-packages",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          },
        },
        :droplets => {
          :droplet_directory_key => "cc-droplets",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          },
        },

        :db => {
          :log_level => "debug",
          :database => db_connection_string,
          :pool_timeout => 10
        }
      )

      config_hash
    end

    private

    def prepare_database
      if db.database_type == :postgres
        db.execute("CREATE EXTENSION IF NOT EXISTS citext")
      end
    end

    def drop_table_unsafely(table)
      case db.database_type
      when :sqlite
        db.execute("PRAGMA foreign_keys = OFF")
        db.drop_table(table)
        db.execute("PRAGMA foreign_keys = ON")

      when :mysql
        db.execute("SET foreign_key_checks = 0")
        db.drop_table(table)
        db.execute("SET foreign_key_checks = 1")

        # Postgres uses CASCADE directive in DROP TABLE
        # to remove foreign key contstraints.
        # http://www.postgresql.org/docs/9.2/static/sql-droptable.html
      else
        db.drop_table(table, :cascade => true)
      end
    end
  end
end

$spec_env = VCAP::CloudController::SpecEnvironment.new

module VCAP::CloudController::SpecHelper
  def db
    $spec_env.db
  end

  # Clears the config_override and sets config to the default
  def config_reset
    config_override({})
  end

  # Sets a hash of configurations to merge with the defaults
  def config_override(hash)
    @config_override = hash || {}

    @config = nil
    config
  end

  # Lazy load the configuration (default + override)
  def config
    @config ||= begin
      config = config_default.merge(@config_override || {})
      configure_components(config)
      config
    end
  end

  def configure
    config
  end

  # Lazy load the default config
  def config_default
    @config_default ||= begin
      $spec_env.config
    end
  end

  def configure_components(config)
    # Always enable Fog mocking (except when using a local provider, which Fog can't mock).
    res_pool_connection_provider = config[:resource_pool][:fog_connection][:provider].downcase
    packages_connection_provider = config[:packages][:fog_connection][:provider].downcase
    Fog.mock! unless (res_pool_connection_provider == "local" || packages_connection_provider == "local")

    # DO NOT override the message bus, use the same mock that's set the first time
    message_bus = VCAP::CloudController::Config.message_bus || CfMessageBus::MockMessageBus.new

    VCAP::CloudController::Config.configure_components(config)
    VCAP::CloudController::Config.configure_components_depending_on_message_bus(message_bus)
    # reset the dependency locator
    CloudController::DependencyLocator.instance.send(:initialize)

    configure_stacks
  end

  def configure_stacks
    stacks_file = File.join(fixture_path, "config/stacks.yml")
    VCAP::CloudController::Stack.configure(stacks_file)
    VCAP::CloudController::Stack.populate
  end

  class TmpdirCleaner
    def self.dir_paths
      @dir_paths ||= []
    end

    def self.clean_later(dir_path)
      dir_path = File.realpath(dir_path)
      tmpdir_path = File.realpath(Dir.tmpdir)

      unless dir_path.start_with?(tmpdir_path)
        raise ArgumentError, "dir '#{dir_path}' is not in #{tmpdir_path}"
      end
      dir_paths << dir_path
    end

    def self.clean
      FileUtils.rm_rf(dir_paths)
      dir_paths.clear
    end

    def self.mkdir
      dir_path = Dir.mktmpdir
      clean_later(dir_path)
      yield(dir_path)
      dir_path
    end
  end

  RSpec.configure do |rspec_config|
    rspec_config.after(:all) do
      TmpdirCleaner.clean
    end
  end

  def create_zip(zip_name, file_count, file_size=1024)
    (file_count * file_size).tap do |total_size|
      files = []
      file_count.times do |i|
        tf = Tempfile.new("ziptest_#{i}")
        files << tf
        tf.write("A" * file_size)
        tf.close
      end

      child = POSIX::Spawn::Child.new("zip", zip_name, *files.map(&:path))
      unless child.status.exitstatus == 0
        raise "Failed zipping:\n#{child.err}\n#{child.out}"
      end
    end
  end

  def create_zip_with_named_files(opts = {})
    file_count = opts[:file_count] || 0
    hidden_file_count = opts[:hidden_file_count] || 0
    file_size = opts[:file_size] || 1024

    result_zip_file = Tempfile.new("tmpzip")

    TmpdirCleaner.mkdir do |tmpdir|
      file_names = file_count.times.map { |i| "ziptest_#{i}" }
      file_names.each { |file_name| create_file(file_name, tmpdir, file_size) }

      hidden_file_names = hidden_file_count.times.map { |i| ".ziptest_#{i}" }
      hidden_file_names.each { |file_name| create_file(file_name, tmpdir, file_size) }

      zip_process = POSIX::Spawn::Child.new(
        "zip", result_zip_file.path, *(file_names | hidden_file_names), :chdir => tmpdir)

      unless zip_process.status.exitstatus == 0
        raise "Failed zipping:\n#{zip_process.err}\n#{zip_process.out}"
      end
    end

    result_zip_file
  end

  def create_file(file_name, dest_dir, file_size)
    File.open(File.join(dest_dir, file_name), "w") do |f|
      f.write("A" * file_size)
    end
  end

  def unzip_zip(file_path)
    TmpdirCleaner.mkdir do |tmpdir|
      child = POSIX::Spawn::Child.new("unzip", "-d", tmpdir, file_path)
      unless child.status.exitstatus == 0
        raise "Failed unzipping:\n#{child.err}\n#{child.out}"
      end
    end
  end

  def list_files(dir_path)
    [].tap do |file_paths|
      Dir.glob("#{dir_path}/**/*", File::FNM_DOTMATCH).each do |file_path|
        next unless File.file?(file_path)
        file_paths << file_path.sub("#{dir_path}/", "")
      end
    end
  end

  def act_as_cf_admin(&block)
    VCAP::CloudController::SecurityContext.stub(:admin? => true)
    block.call
  ensure
    VCAP::CloudController::SecurityContext.unstub(:admin?)
  end

  def with_em_and_thread(opts = {}, &blk)
    auto_stop = opts.has_key?(:auto_stop) ? opts[:auto_stop] : true
    Thread.abort_on_exception = true

    # Make sure that thread pool for defers is 1
    # so that it acts as a simple run loop.
    EM.threadpool_size = 1

    EM.run do
      Thread.new do
        blk.call
        stop_em_when_all_defers_are_done if auto_stop
      end
    end
  end

  def instant_stop_em
    EM.next_tick { EM.stop }
  end

  def stop_em_when_all_defers_are_done
    stop_em = lambda {
      # Account for defers/timers made from within defers/timers
      if EM.defers_finished? && em_timers_finished?
        EM.stop
      else
        # Note: If we put &stop_em in a oneshot timer
        # calling EM.stop does not stop EM; however,
        # calling EM.stop in the next tick does.
        # So let's just do next_tick...
        EM.next_tick(&stop_em)
      end
    }
    EM.next_tick(&stop_em)
  end

  def em_timers_finished?
    all_timers = EM.instance_variable_get("@timers")
    active_timers = all_timers.select { |tid, t| t.respond_to?(:call) }
    active_timers.empty?
  end

  def em_inspect_timers
    puts EM.instance_variable_get("@timers").inspect
  end

  def fixture_path
    File.expand_path("../fixtures", __FILE__)
  end

  RSpec::Matchers.define :be_recent do |expected|
    match do |actual|
      actual.should be_within(5).of(Time.now)
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
        decoded_response["description"].should match(/#{description_match}/)
      end
    end
  end

  shared_context "resource pool" do
    before(:all) do
      num_dirs = 3
      num_unique_allowed_files_per_dir = 7
      file_duplication_factor = 2
      @max_file_size = 1098 # this is arbitrary

      @total_allowed_files =
        num_dirs * num_unique_allowed_files_per_dir * file_duplication_factor

      @dummy_descriptor = {"sha1" => Digest::SHA1.hexdigest("abc"), "size" => 1}
      @tmpdir = Dir.mktmpdir

      @descriptors = []
      num_dirs.times do
        dirname = SecureRandom.uuid
        Dir.mkdir("#{@tmpdir}/#{dirname}")
        num_unique_allowed_files_per_dir.times do
          basename = SecureRandom.uuid
          path = "#{@tmpdir}/#{dirname}/#{basename}"
          contents = SecureRandom.uuid

          descriptor = {
            "sha1" => Digest::SHA1.hexdigest(contents),
            "size" => contents.length
          }
          @descriptors << descriptor

          file_duplication_factor.times do |i|
            File.open("#{path}-#{i}", "w") do |f|
              f.write contents
            end
          end

          File.open("#{path}-not-allowed", "w") do |f|
            f.write "A" * @max_file_size
          end
        end
      end

      Fog.mock!
    end

    let(:resource_pool_config) do
      {
        :maximum_size => @max_file_size,
        :resource_directory_key => "spec-cc-resources",
        :fog_connection => {
          :provider => "AWS",
          :aws_access_key_id => "fake_aws_key_id",
          :aws_secret_access_key => "fake_secret_access_key",
        }
      }
    end

    before do
      @resource_pool = VCAP::CloudController::ResourcePool.new(
        :resource_pool => resource_pool_config
      )
    end

    after(:all) do
      FileUtils.rm_rf(@tmpdir)
    end
  end

  shared_context "with valid resource in resource pool" do
    let(:valid_resource) do
      pending("Deprecated")
      file = Tempfile.new("mytemp")
      file.write("A" * 1024)
      file.close

      VCAP::CloudController::ResourcePool.instance.add_path(file.path)
      file_sha1 = Digest::SHA1.file(file.path).hexdigest

      {"fn" => "file/path", "sha1" => file_sha1, "size" => 2048}
    end
  end
end

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |file| require file }

RSpec.configure do |rspec_config|
  def rspec_config.escaped_path(*parts)
    Regexp.compile(parts.join('[\\\/]'))
  end

  rspec_config.treat_symbols_as_metadata_keys_with_true_values = true

  rspec_config.include Rack::Test::Methods
  rspec_config.include VCAP::CloudController
  rspec_config.include VCAP::CloudController::SpecHelper
  rspec_config.include VCAP::CloudController::BrokerApiHelper
  rspec_config.include ModelCreation
  rspec_config.extend ModelCreation
  rspec_config.include ServicesHelpers, services: true
  rspec_config.include ModelHelpers
  rspec_config.include TempFileCreator

  rspec_config.after do |example|
    example.delete_created_temp_files
  end

  rspec_config.include ControllerHelpers, type: :controller, :example_group => {
    :file_path => rspec_config.escaped_path(%w[spec controllers])
  }

  rspec_config.include ControllerHelpers, type: :api, :example_group => {
    :file_path => rspec_config.escaped_path(%w[spec api])
  }

  rspec_config.include AcceptanceHelpers, type: :acceptance, :example_group => {
    :file_path => rspec_config.escaped_path(%w[spec acceptance])
  }

  rspec_config.include ApiDsl, type: :api, :example_group => {
    :file_path => rspec_config.escaped_path(%w[spec api])
  }

  rspec_config.before :all do
    VCAP::CloudController::SecurityContext.clear

    RspecApiDocumentation.configure do |c|
      c.format = [:html, :json]
      c.api_name = "Cloud Foundry API"
      c.template_path = "spec/api/documentation/templates"
      c.curl_host = "https://api.[your-domain.com]"
      c.app = Struct.new(:config) do
        # generate app() method for rack::test to use
        include ::ControllerHelpers
      end.new(config).app
    end
  end

  rspec_config.before :each do
    Fog::Mock.reset
    Sequel::Deprecation.output = StringIO.new
    Sequel::Deprecation.backtrace_filter = 5

    config_reset
  end

  rspec_config.after :each do
    expect(Sequel::Deprecation.output.string).to eq ''
    Sequel::Deprecation.output.close unless Sequel::Deprecation.output.closed?
  end

  rspec_config.around :each do |example|
    if example.metadata.to_s.include? "non_transactional"
      begin
        example.run
      ensure
        $spec_env.reset_database_with_seeds
      end
    else
      Sequel::Model.db.transaction(rollback: :always) do
        example.run
      end
    end
  end
end

# Ensures that entries are not returned ordered by the id field by
# default. Breaks the tests (deliberately) unless we order by id
# explicitly. In sqlite, the default ordering, although not guaranteed,
# is de facto by id. In postgres the order is random unless specified.
class VCAP::CloudController::App
  set_dataset dataset.order(:guid)
end

class VCAP::CloudController::ModelManager
  def initialize(*models)
    @models = models
    @instances = []
  end

  def record
    raise StandardError "Recording already enabled" if @models.nil?

    @models.each do |model|
      original_make = model.method(:make)
      model.stub(:make) do |*args, &block|
        result = original_make.call(*args, &block)
        @instances << result unless result.nil?
        result
      end
    end
    @models = nil
  end

  def destroy
    raise StandardError "Model instances already destroyed" if @instances.nil?
    @instances.each do |instance|
      instance.destroy
    end
    @instances = nil
  end
end
