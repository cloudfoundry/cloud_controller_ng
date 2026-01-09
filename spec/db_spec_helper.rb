unless defined?(SPEC_HELPER_LOADED)
  require 'lightweight_spec_helper'

  require 'rspec/collection_matchers'

  require 'rails'
  require 'support/bootstrap/spec_bootstrap'
  require 'support/database_isolation'
  require 'sequel_plugins/sequel_plugins'

  require 'machinist/sequel'
  require 'machinist/object'

  VCAP::CloudController::SpecBootstrap.init(recreate_test_tables: false)

  require 'delayed_job_plugins/deserialization_retry'
  require 'delayed_job_plugins/after_enqueue_hook'
  require 'delayed_job_plugins/before_enqueue_hook'
  require 'delayed_job_plugins/delayed_jobs_metrics'

  require 'support/fakes/blueprints'

  RSpec.configure do |rspec_config|
    rspec_config.before :suite do
      VCAP::CloudController::SpecBootstrap.seed
    end

    rspec_config.around do |example|
      isolation = DatabaseIsolation.choose(example.metadata[:isolation], DbConfig.new.connection)
      isolation.cleanly { example.run }
    end
  end
end
