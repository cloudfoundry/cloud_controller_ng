class RakeConfig
  class << self
    def context
      @context || :api
    end

    def context=(context)
      @context = context
    end

    def config
      secrets_hash = {}
      # TODO: require secrets fetcher?
      secrets_hash = VCAP::CloudController::SecretsFetcher.fetch_secrets_from_file(secrets_file) unless secrets_file.nil?

      VCAP::CloudController::Config.load_from_file(config_file, context: context, secrets_hash: secrets_hash)
    end

    private

    def config_file
      if ENV['CLOUD_CONTROLLER_NG_CONFIG']
        return ENV['CLOUD_CONTROLLER_NG_CONFIG']
      end

      [File.expand_path('../../config/cloud_controller.yml', __dir__),
       '/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml'].find { |candidate| candidate && File.exist?(candidate) }
    end

    def secrets_file
      if ENV['CLOUD_CONTROLLER_NG_SECRETS']
        return ENV['CLOUD_CONTROLLER_NG_SECRETS']
      end
    end
  end
end
