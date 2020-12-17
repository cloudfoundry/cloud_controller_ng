unless defined?(SPEC_HELPER_LOADED)
  require 'lightweight_spec_helper'

  require 'rspec/collection_matchers'

  require 'rails'
  require 'support/bootstrap/spec_bootstrap'
  require 'support/database_isolation'
  require 'sequel_plugins/sequel_plugins'

  require 'machinist/sequel'
  require 'machinist/object'

  VCAP::CloudController::SpecBootstrap.init(recreate_tables: false)

  require 'delayed_job_plugins/deserialization_retry'
  require 'delayed_job_plugins/after_enqueue_hook'
  require 'delayed_job_plugins/before_enqueue_hook'

  require 'support/fakes/blueprints'

  RSpec.configure do |rspec_config|
    rspec_config.before :suite do
      VCAP::CloudController::SpecBootstrap.seed
    end

    rspec_config.around :each do |example|
      # DatabaseIsolation requires the api config context
      TestConfig.context = :api
      TestConfig.reset

      isolation = DatabaseIsolation.choose(example.metadata[:isolation], TestConfig.config_instance, DbConfig.new.connection)
      isolation.cleanly { example.run }
    end
  end
end
