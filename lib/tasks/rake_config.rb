class RakeConfig
  def self.config
    @config ||= begin
      config_file = ENV['CLOUD_CONTROLLER_NG_CONFIG'] || File.expand_path('../../../config/cloud_controller.yml', __FILE__)
      config = VCAP::CloudController::Config.from_file(config_file)
      config
    end
  end
end
