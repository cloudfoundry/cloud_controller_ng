class RakeConfig
  class << self
    def context
      @context || :api
    end

    def context=(context)
      @context = context
    end

    def config
      VCAP::CloudController::Config.load_from_file(get_config_file, context: context)
    end

    private

    def get_config_file
      if ENV['CLOUD_CONTROLLER_NG_CONFIG']
        return ENV['CLOUD_CONTROLLER_NG_CONFIG']
      end
      [File.expand_path('../../config/cloud_controller.yml', __dir__),
        '/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml'].find { |candidate| candidate && File.exists?(candidate) }
    end
  end
end
