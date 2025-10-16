require 'spec_helper'
require 'migrations/helpers/bigint_migration_step3_shared_context'

RSpec.describe 'bigint migration - delayed jobs table - step3a', isolation: :truncation, type: :migration do
  include_context 'bigint migration step3a' do
    let(:migration_filename_step1) { '20250729142800_bigint_migration_delayed_jobs_step1.rb' }
    let(:migration_filename_step3a) { '20250930135451_bigint_migration_delayed_jobs_step3a_spec.rb' }
    let(:table) { :delayed_jobs }
    let(:insert) do
      lambda do |db|
        db[:delayed_jobs].insert(guid: SecureRandom.uuid, created_at: Time.now.utc, updated_at: Time.now.utc)
      end
    end
  end
end
