namespace :buildpacks do
  desc 'Check Installed Stacks'
  task stack_check: :environment do
    VCAP::CloudController::Encryptor.db_encryption_key = RakeConfig.config.get(:db_encryption_key)
    require 'models/runtime/buildpack_lifecycle_data_model'
    require 'models/runtime/stack'

    deprecated_stack = 'cflinuxfs3'
    stack_config = VCAP::CloudController::Stack::ConfigFile.new(RakeConfig.config.get(:stacks_file))
    p stack_config.stacks
    configured_stacks = stack_config.stacks
    deprecated_stack_in_config = (configured_stacks.find { |stack| stack['name'] == deprecated_stack }).nil?
    p(configured_stacks.find { |stack| stack['name'] == deprecated_stack })
    p deprecated_stack_in_config
    p deprecated_stack_in_config.nil?

    exit(0) if deprecated_stack_in_config

    logger = Steno.logger('cc.stack')
    VCAP::CloudController::DB.connect(RakeConfig.config.get(:db), logger)
    deprecated_stack_in_db = VCAP::CloudController::Stack.first(name: deprecated_stack).present?
    if deprecated_stack_in_db
      logger.error('rake task \'stack_check\' failed, ' + deprecated_stack + ' is not supported')
      exit(1)
    end
  end
end
