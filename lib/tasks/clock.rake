namespace :clock do
  desc "Start a recurring tasks"
  task :start do
    require "cloud_controller/clock"

    BackgroundJobEnvironment.new(config).setup_environment
    VCAP::CloudController::Clock.start
  end
end
