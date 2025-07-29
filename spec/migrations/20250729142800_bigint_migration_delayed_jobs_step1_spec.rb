require 'spec_helper'
require 'migrations/helpers/bigint_migration_step1_shared_context'

RSpec.describe 'bigint migration - delayed_jobs table - step1', isolation: :truncation, type: :migration do
  include_context 'bigint migration step1' do
    let(:migration_filename) { '20250729142800_bigint_migration_delayed_jobs_step1.rb' }
    let(:table) { :delayed_jobs }
    let(:insert) do
      lambda do |db|
        db[:delayed_jobs].insert(guid: SecureRandom.uuid)
      end
    end
  end
end
