$:.unshift(File.expand_path("../../lib", __FILE__))
$:.unshift(File.expand_path("../../app", __FILE__))

require "rubygems"
require "bundler"
require "bundler/setup"

require "machinist/sequel"
require "machinist/object"
require "rack/test"
require "timecop"

require "steno"
require "webmock/rspec"
require "cf_message_bus/mock_message_bus"

require "cloud_controller"

module VCAP::CloudController
  class SpecEnvironment
    def initialize
      ENV["CC_TEST"] = "true"
      FileUtils.mkdir_p(artifacts_dir)

      # ignore the race when we run specs in parallel
      begin
        File.unlink(log_filename)
      rescue Errno::ENOENT
      end

      Steno.init(Steno::Config.new(
        :default_log_level => "debug",
        :sinks => [Steno::Sink::IO.for_file(log_filename)]
      ))
      reset_database
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

      VCAP::CloudController::DB.apply_migrations(db)
    end

    def db
      db_connection = "sqlite:///"
      db_index = ""

      if ENV["DB_CONNECTION"]
        db_connection = ENV["DB_CONNECTION"]
        db_index = ENV["TEST_ENV_NUMBER"]
      end

      @db ||= VCAP::CloudController::DB.connect(
        db_logger,
        :database => "#{db_connection}#{db_index}",
        :log_level => "debug2"
      )
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

  def reset_database
    $spec_env.reset_database
    VCAP::CloudController::Seeds.create_seed_quota_definitions(config)
  end

  # Note that this method is mixed into each example, and so the instance
  # variable we created here gets cleared automatically after each example
  def config_override(hash)
    @config_override ||= {}
    @config_override.update(hash)

    @config = nil
    config
  end

  def config
    @config ||= begin
      config_file = File.expand_path("../../config/cloud_controller.yml", __FILE__)
      config_hash = VCAP::CloudController::Config.from_file(config_file)

      config_hash.merge!(
        :nginx => {:use_nginx => true},
        :resource_pool => {
          :resource_directory_key => "spec-cc-resources",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          }
        },
        :packages => {
          :app_package_directory_key => "cc-packages",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          }
        },
        :droplets => {
          :droplet_directory_key => "cc-droplets",
          :fog_connection => {
            :provider => "AWS",
            :aws_access_key_id => "fake_aws_key_id",
            :aws_secret_access_key => "fake_secret_access_key",
          }
        }
      )

      config_hash.merge!(@config_override || {})

      res_pool_connection_provider = config_hash[:resource_pool][:fog_connection][:provider].downcase
      packages_connection_provider = config_hash[:packages][:fog_connection][:provider].downcase
      Fog.mock! unless (res_pool_connection_provider == "local" || packages_connection_provider == "local")

      configure_components(config_hash)
      config_hash
    end
  end

  def configure_components(config)
    VCAP::CloudController::Config.db_encryption_key = "some-key"
    mbus = CfMessageBus::MockMessageBus.new

    # FIXME: this is better suited for a before-each stub so that we can unstub it in examples
    VCAP::CloudController::Models::ManagedServiceInstance.gateway_client_class = VCAP::Services::Api::ServiceGatewayClientFake

    VCAP::CloudController::AccountCapacity.configure(config)
    VCAP::CloudController::ResourcePool.instance =
      VCAP::CloudController::ResourcePool.new(config)
    VCAP::CloudController::AppPackage.configure(config)

    stager_pool = VCAP::CloudController::StagerPool.new(config, mbus)
    VCAP::CloudController::AppManager.configure(config, mbus, stager_pool)
    VCAP::CloudController::Staging.configure(config)

    dea_pool = VCAP::CloudController::DeaPool.new(mbus)
    VCAP::CloudController::DeaClient.configure(config, mbus, dea_pool)

    VCAP::CloudController::HealthManagerClient.configure(config, mbus)

    VCAP::CloudController::LegacyBulk.configure(config, mbus)
    VCAP::CloudController::Models::QuotaDefinition.configure(config)
    VCAP::CloudController::Models::ServicePlan.configure(config[:trial_db])

    configure_stacks
  end

  def configure_stacks
    stacks_file = File.join(fixture_path, "config/stacks.yml")
    VCAP::CloudController::Models::Stack.configure(stacks_file)
    VCAP::CloudController::Models::Stack.populate
  end

  def configure
    config
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
    VCAP::CloudController::SecurityContext.stub(:current_user_is_admin? => true)
    block.call
  ensure
    VCAP::CloudController::SecurityContext.unstub(:current_user_is_admin?)
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
      file = Tempfile.new("mytemp")
      file.write("A" * 1024)
      file.close

      VCAP::CloudController::ResourcePool.instance.add_path(file.path)
      file_sha1 = Digest::SHA1.file(file.path).hexdigest

      {"fn" => "file/path", "sha1" => file_sha1, "size" => 2048}
    end
  end
end

class CF::UAA::Misc
  def self.validation_key(*args)
    raise CF::UAA::TargetError.new('error' => 'unauthorized')
  end
end

class Redis
  def self.new(*args)
    MockRedis.new
  end
end

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |file| require file }

RSpec.configure do |rspec_config|
  rspec_config.treat_symbols_as_metadata_keys_with_true_values = true

  rspec_config.include Rack::Test::Methods
  rspec_config.include VCAP::CloudController
  rspec_config.include VCAP::CloudController::SpecHelper
  rspec_config.include ModelCreation
  rspec_config.extend ModelCreation
  rspec_config.include ServicesHelpers, services: true

  rspec_config.before(:all) do
    VCAP::CloudController::SecurityContext.clear
    configure
  end

  rspec_config.before :each do
    # We need to stub out this because it's in an after_destroy_commit hook
    # Is event emitter our salvation?
    VCAP::CloudController::AppManager.stub(:delete_droplet)
    VCAP::CloudController::AppPackage.stub(:delete_package)
  end
end

require "cloud_controller/models"
Dir.glob(File.join(File.dirname(__FILE__), "support/**/*.rb")).each { |f| require f }

require "cloud_controller/models"
