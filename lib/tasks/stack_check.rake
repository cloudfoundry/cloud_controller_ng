namespace :stacks do
  desc 'Check Installed Stacks'
  task stack_check: :environment do
    logger = Steno.logger('cc.stack')
    db = VCAP::CloudController::DB.connect(RakeConfig.config.get(:db), logger)
    next unless db.table_exists?(:stacks)
    next unless db.table_exists?(:buildpack_lifecycle_data)

    RakeConfig.config.load_db_encryption_key
    require 'models/runtime/buildpack_lifecycle_data_model'
    require 'models/runtime/stack'
    require 'cloud_controller/check_stacks'
    VCAP::CloudController::CheckStacks.new(RakeConfig.config).validate_stacks
  end
end
