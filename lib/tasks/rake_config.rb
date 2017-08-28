class RakeConfig
  def self.config
    @config ||= begin
      config_file = ENV['CLOUD_CONTROLLER_NG_CONFIG'] || File.expand_path('../../../config/cloud_controller.yml', __FILE__)
      VCAP::CloudController::Config.load_from_file(config_file)
    end
  end
end
