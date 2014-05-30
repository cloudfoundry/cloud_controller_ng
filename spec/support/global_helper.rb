module VCAP::CloudController::GlobalHelper
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
    File.expand_path("../../fixtures", __FILE__)
  end
end
