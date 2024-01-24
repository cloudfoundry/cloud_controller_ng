class RakeConfig
  class << self
    def context
      @context || :api
    end

    attr_writer :context

    def config
      secrets_hash = {}
      # TODO: require secrets fetcher?
      secrets_hash = VCAP::CloudController::SecretsFetcher.fetch_secrets_from_file(secrets_file) unless secrets_file.nil?

      api_config_hash = VCAP::CloudController::Config.read_file(config_file)

      if context == :api
        local_worker_config_hash = VCAP::CloudController::Config.read_file(cc_local_worker_config_file)
        api_config_hash = api_config_hash.deep_merge(local_worker_config_hash)
      end

      VCAP::CloudController::Config.load_from_hash(api_config_hash, context:, secrets_hash:)
    end

    private

    def cc_local_worker_config_file
      return ENV['CLOUD_CONTROLLER_LOCAL_WORKER_OVERRIDE_CONFIG'] if ENV['CLOUD_CONTROLLER_LOCAL_WORKER_OVERRIDE_CONFIG']

      [File.expand_path('../../config/cloud_controller_local_worker_override.yml', __dir__),
       '/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_local_worker_override.yml'].find { |candidate| candidate && File.exist?(candidate) }
    end

    def config_file
      return ENV['CLOUD_CONTROLLER_NG_CONFIG'] if ENV['CLOUD_CONTROLLER_NG_CONFIG']

      [File.expand_path('../../config/cloud_controller.yml', __dir__),
       '/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml'].find { |candidate| candidate && File.exist?(candidate) }
    end

    def secrets_file
      return unless ENV['CLOUD_CONTROLLER_NG_SECRETS']

      ENV.fetch('CLOUD_CONTROLLER_NG_SECRETS', nil)
    end
  end
end
