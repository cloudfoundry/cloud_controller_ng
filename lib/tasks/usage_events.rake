namespace :db do
  desc 'Seed usage events'
  task seed_usage_events: :environment do
    $LOAD_PATH.unshift(File.expand_path('../../spec', __dir__))

    require 'machinist/sequel'
    require 'machinist/object'
    require 'support/bootstrap/spec_bootstrap'

    # Initialize the test environment
    VCAP::CloudController::SpecBootstrap.init

    require File.expand_path('../../db/seeds/usage_events', __dir__)
    puts 'Created seed usage events'
  end
end
