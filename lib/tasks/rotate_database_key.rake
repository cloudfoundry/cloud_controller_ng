namespace :rotate_cc_database_key do
  desc 'Rotate database keys'
  task perform: :environment do
    require 'cloud_controller/errands/rotate_database_key'
    RakeConfig.context = :rotate_database_key
    BoshErrandEnvironment.new(RakeConfig.config).setup_environment
    VCAP::CloudController::RotateDatabaseKey.perform
  end

  desc 'Check if database rows need re-encryption with the current key'
  task check: :environment do
    require 'cloud_controller/errands/check_database_encryption_key'
    RakeConfig.context = :rotate_database_key
    BoshErrandEnvironment.new(RakeConfig.config).setup_environment
    VCAP::CloudController::CheckDatabaseEncryptionKey.perform
  end
end
