namespace :clock do
  desc "Start a recurring tasks"
  task :start do
    require "cloud_controller/clock"

    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
    clock = VCAP::CloudController::Clock.new(RakeConfig.config)
    clock.start
  end
end
