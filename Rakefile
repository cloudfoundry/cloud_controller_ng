$:.unshift(File.expand_path("../lib", __FILE__))
$:.unshift(File.expand_path("../app", __FILE__))

require "yaml"
require "sequel"
require "steno"
require "cloud_controller"

def config
  @config ||= begin
    config_file = ENV["CLOUD_CONTROLLER_NG_CONFIG"] || File.expand_path("../config/cloud_controller.yml", __FILE__)
    config = VCAP::CloudController::Config.from_file(config_file)
    config
  end
end

Dir["lib/tasks/**/*.rake"].each do |tasks|
  load tasks
end

task default: [:rubocop, :spec]
