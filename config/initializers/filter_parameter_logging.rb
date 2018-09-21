# Be sure to restart your server when you modify this file.

module CCInitializers
  def self.filter_parameter_logging(_)
    # Configure sensitive parameters which will be filtered from the log file.
    Rails.application.config.filter_parameters += [:password]
  end
end
