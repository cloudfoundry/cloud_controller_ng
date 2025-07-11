require 'spec_helper'
require 'migrations/helpers/bigint_migration_step3_shared_context'

RSpec.describe 'bigint migration - events table - step3b', isolation: :truncation, type: :migration do
  include_context 'bigint migration step3b' do
    let(:migration_filename_step1) { '20250327142351_bigint_migration_events_step1.rb' }
    let(:migration_filename_step3a) { '20250603103400_bigint_migration_events_step3a.rb' }
    let(:migration_filename_step3b) { '20250603103500_bigint_migration_events_step3b.rb' }
    let(:table) { :events }
    let(:insert) do
      lambda do |db|
        db[:events].insert(guid: SecureRandom.uuid, timestamp: Time.now.utc, type: 'type',
                           actor: 'actor', actor_type: 'actor_type',
                           actee: 'actee', actee_type: 'actee_type')
      end
    end
  end
end
