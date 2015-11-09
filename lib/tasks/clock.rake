namespace :clock do
  desc "Start a recurring tasks"
  task :start do
    require "cloud_controller/scheduler"

    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
    scheduler = VCAP::CloudController::Scheduler.new(RakeConfig.config)
    scheduler.start
  end
end
