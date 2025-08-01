require 'spec_helper'
require 'migrations/helpers/bigint_migration_step1_shared_context'

RSpec.describe 'bigint migration - app_usage_events table - step1', isolation: :truncation, type: :migration do
  include_context 'bigint migration step1' do
    let(:migration_filename) { '20250729143000_bigint_migration_app_usage_events_step1.rb' }
    let(:table) { :app_usage_events }
    let(:insert) do
      lambda do |db|
        db[:app_usage_events].insert(guid: SecureRandom.uuid, created_at: Time.now.utc, instance_count: 1,
                                     memory_in_mb_per_instance: 2, state: 'state', app_guid: 'app_guid',
                                     app_name: 'app_name', space_guid: 'space_guid', space_name: 'space_name',
                                     org_guid: 'org_guid')
      end
    end
  end
end
