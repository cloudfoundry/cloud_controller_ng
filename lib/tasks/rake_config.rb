class RakeConfig
  class << self
    def context
      @context || :api
    end

    def context=(context)
      @context = context
    end

    def config
      VCAP::CloudController::Config.load_from_file(config_file, context: context)
    end

    private

    def config_file
      if ENV['CLOUD_CONTROLLER_NG_CONFIG']
        return ENV['CLOUD_CONTROLLER_NG_CONFIG']
      end

      [File.expand_path('../../config/cloud_controller.yml', __dir__),
       '/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml'].find { |candidate| candidate && File.exist?(candidate) }
    end
  end
end
