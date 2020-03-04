namespace :clock do
  desc 'Start a recurring tasks'
  task :start do
    require 'cloud_controller/clock/scheduler'

    RakeConfig.context = :clock
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment(RakeConfig.config.get(:readiness_ports,
                                                                                            :cloud_controller_clock))
    scheduler = VCAP::CloudController::Scheduler.new(RakeConfig.config)
    scheduler.start
  end
end
