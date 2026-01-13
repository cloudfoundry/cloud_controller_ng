namespace :deployment_updater do
  desc 'Start a recurring process to perform zero downtime deployments'
  task start: :environment do
    puts RUBY_DESCRIPTION
    require 'cloud_controller/deployment_updater/scheduler'
    require 'cloud_controller/execution_context'

    VCAP::CloudController::ExecutionContext::DEPLOYMENT_UPDATER.set_rake_context
    VCAP::CloudController::ExecutionContext::DEPLOYMENT_UPDATER.set_process_type_env
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment(RakeConfig.config.get(:readiness_port,
                                                                                            :deployment_updater))
    VCAP::CloudController::DeploymentUpdater::Scheduler.start
  end
end
