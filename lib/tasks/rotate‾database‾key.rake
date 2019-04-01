namespace :rotate_cc_database_key do
  desc 'Rotate database keys'
  task :perform do
    require 'cloud_controller/errands/rotate_database_key'
    RakeConfig.context = :rotate_database_key
    BoshErrandEnvironment.new(RakeConfig.config).setup_environment
    VCAP::CloudController::RotateDatabaseKey.perform
  end
end
