namespace :route_syncer do
  desc 'Start a recurring route sync'
  task :start do
    require 'cloud_controller/copilot/scheduler'

    RakeConfig.context = :route_syncer
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
    VCAP::CloudController::Copilot::Scheduler.start
  end
end
