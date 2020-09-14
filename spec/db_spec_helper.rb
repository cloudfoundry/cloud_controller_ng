require 'lightweight_spec_helper'

require 'rspec/collection_matchers'

require 'rails'
require 'support/bootstrap/spec_bootstrap'
require 'sequel_plugins/sequel_plugins'

require 'machinist/sequel'
require 'machinist/object'

VCAP::CloudController::SpecBootstrap.init

require 'support/fakes/blueprints'

RSpec.configure do |rspec_config|
  rspec_config.before :suite do
    VCAP::CloudController::SpecBootstrap.seed
  end
end
