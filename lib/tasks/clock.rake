namespace :clock do
  desc 'Start a recurring tasks'
  task start: :environment do
    puts RUBY_DESCRIPTION

    require 'cloud_controller/clock/scheduler'

    RakeConfig.context = :clock
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment(RakeConfig.config.get(:readiness_port,
                                                                                            :clock))
    scheduler = VCAP::CloudController::Scheduler.new(RakeConfig.config)
    scheduler.start
  end
end
