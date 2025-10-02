require 'spec_helper'
require 'migrations/helpers/bigint_migration_step3_shared_context'

RSpec.describe 'bigint migration - jobs table - step3b', isolation: :truncation, type: :migration do
  include_context 'bigint migration step3b' do
    let(:migration_filename_step1) { '20250729142900_bigint_migration_jobs_step1.rb' }
    let(:migration_filename_step3a) { '20250930135517_bigint_migration_jobs_step3a.rb' }
    let(:migration_filename_step3b) { '20250930135527_bigint_migration_jobs_step3b.rb' }
    let(:table) { :jobs }
    let(:insert) do
      lambda do |db|
        db[:jobs].insert(guid: SecureRandom.uuid, created_at: Time.now.utc, updated_at: Time.now.utc)
      end
    end
  end
end
