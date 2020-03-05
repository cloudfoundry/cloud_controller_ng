namespace :deployment_updater do
  desc 'Start a recurring process to perform zero downtime deployments'
  task :start do
    require 'cloud_controller/deployment_updater/scheduler'

    RakeConfig.context = :deployment_updater
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
    VCAP::CloudController::DeploymentUpdater::Scheduler.start
  end
end
