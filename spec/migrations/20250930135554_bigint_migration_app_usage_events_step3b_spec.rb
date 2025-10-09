require 'spec_helper'
require 'migrations/helpers/bigint_migration_step3_shared_context'

RSpec.describe 'bigint migration - app_usage_events table - step3b', isolation: :truncation, type: :migration do
  include_context 'bigint migration step3b' do
    let(:migration_filename_step1) { '20250729143000_bigint_migration_app_usage_events_step1.rb' }
    let(:migration_filename_step3a) { '20250930135548_bigint_migration_app_usage_events_step3a.rb' }
    let(:migration_filename_step3b) { '20250930135554_bigint_migration_app_usage_events_step3b.rb' }
    let(:table) { :app_usage_events }
    let(:insert) do
      lambda do |db|
        db[:app_usage_events].insert(guid: SecureRandom.uuid, created_at: Time.now.utc, instance_count: 1,
                                     memory_in_mb_per_instance: 512, state: 'teststate',
                                     app_guid: SecureRandom.uuid, app_name: 'testapp',
                                     space_guid: SecureRandom.uuid, space_name: 'testspace',
                                     org_guid: SecureRandom.uuid)
      end
    end
  end
end
