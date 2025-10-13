require 'spec_helper'
require 'migrations/helpers/bigint_migration_step3_shared_context'

RSpec.describe 'bigint migration - service_usage_events table - step3a', isolation: :truncation, type: :migration do
  include_context 'bigint migration step3a' do
    let(:migration_filename_step1) { '20250729143100_bigint_migration_service_usage_events_step1.rb' }
    let(:migration_filename_step3a) { '20250930135612_bigint_migration_service_usage_events_step3a.rb' }
    let(:table) { :service_usage_events }
    let(:insert) do
      lambda do |db|
        db[:service_usage_events].insert(guid: SecureRandom.uuid, created_at: Time.now.utc,
                                         state: 'teststate', org_guid: SecureRandom.uuid,
                                         space_guid: SecureRandom.uuid, space_name: 'testspace',
                                         service_instance_guid: SecureRandom.uuid, service_instance_name: 'testinstance',
                                         service_instance_type: 'testtype')
      end
    end
  end
end
