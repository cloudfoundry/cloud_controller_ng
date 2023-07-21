namespace :route_syncer do
  desc 'Start a recurring route sync'
  task start: :environment do
    RakeConfig.context = :route_syncer
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
  end
end
