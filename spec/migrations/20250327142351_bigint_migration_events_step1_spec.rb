require 'spec_helper'
require 'migrations/helpers/bigint_migration_step1_shared_context'

RSpec.describe 'bigint migration - events table - step1', isolation: :truncation, type: :migration do
  include_context 'bigint migration step1' do
    let(:migration_filename) { '20250327142351_bigint_migration_events_step1.rb' }
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
