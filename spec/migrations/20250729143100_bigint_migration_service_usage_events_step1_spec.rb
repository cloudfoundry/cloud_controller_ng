require 'spec_helper'
require 'migrations/helpers/bigint_migration_step1_shared_context'

RSpec.describe 'bigint migration - service_usage_events table - step1', isolation: :truncation, type: :migration do
  include_context 'bigint migration step1' do
    let(:migration_filename) { '20250729143100_bigint_migration_service_usage_events_step1.rb' }
    let(:table) { :service_usage_events }
    let(:insert) do
      lambda do |db|
        db[:service_usage_events].insert(guid: SecureRandom.uuid, created_at: Time.now.utc, state: 'state',
                                         org_guid: 'org_guid', space_guid: 'space_guid', space_name: 'space_name',
                                         service_instance_guid: 'si_guid', service_instance_name: 'si_name',
                                         service_instance_type: 'si_type')
      end
    end
  end
end
