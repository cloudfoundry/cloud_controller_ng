class RakeConfig
  class << self
    def context
      @context || :api
    end

    def context=(context)
      @context = context
    end

    def config
      config_file = ENV['CLOUD_CONTROLLER_NG_CONFIG'] || File.expand_path('../../../config/cloud_controller.yml', __FILE__)
      VCAP::CloudController::Config.load_from_file(config_file, context: context)
    end
  end
end
