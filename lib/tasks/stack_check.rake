namespace :stacks do
  desc 'Check Installed Stacks'
  task stack_check: :environment do
    logger = Steno.logger('cc.stack')
    VCAP::CloudController::Encryptor.db_encryption_key = RakeConfig.config.get(:db_encryption_key)
    VCAP::CloudController::DB.connect(RakeConfig.config.get(:db), logger)

    require 'models/runtime/buildpack_lifecycle_data_model'
    require 'models/runtime/stack'
    require 'cloud_controller/check_stacks'

    VCAP::CloudController::CheckStacks.new(RakeConfig.config).validate_stacks
  end
end
