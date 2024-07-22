namespace :stacks do
  desc 'Check Installed Stacks'
  task stack_check: :environment do
    require 'cloud_controller/check_stacks'

    BackgroundJobEnvironment.new(RakeConfig.config).setup_environment do
      VCAP::CloudController::CheckStacks.new(RakeConfig.config).validate_stacks
    end
  end
end
