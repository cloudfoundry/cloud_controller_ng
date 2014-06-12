require "bootstrap/default_config"

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

  def config_default
    @config_default ||= DefaultConfig.for_specs
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
    stacks_file = File.join(Paths::FIXTURES, "config/stacks.yml")
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
end
