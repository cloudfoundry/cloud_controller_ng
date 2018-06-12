namespace :database_key_rotator do
  desc 'Rotate database keys'
  task :perform do
    require 'cloud_controller/errands/rotate_database_key'
    RakeConfig.context = :database_key_rotator
    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment
    VCAP::CloudController::RotateDatabaseKey.perform
  end
end
