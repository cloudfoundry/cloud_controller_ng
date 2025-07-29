require 'spec_helper'
require 'migrations/helpers/bigint_migration_step1_shared_context'

RSpec.describe 'bigint migration - jobs table - step1', isolation: :truncation, type: :migration do
  include_context 'bigint migration step1' do
    let(:migration_filename) { '20250729142900_bigint_migration_jobs_step1.rb' }
    let(:table) { :jobs }
    let(:insert) do
      lambda do |db|
        db[:jobs].insert(guid: SecureRandom.uuid)
      end
    end
  end
end
