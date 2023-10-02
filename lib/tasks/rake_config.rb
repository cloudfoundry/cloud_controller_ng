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

      VCAP::CloudController::Config.load_from_file(config_file, context:, secrets_hash:)
    end

    private

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
