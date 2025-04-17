require 'spec_helper'
require 'database/bigint_migration'

RSpec.describe VCAP::BigintMigration do
  let(:skip_bigint_id_migration) { nil }

  before do
    allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
  end

  describe 'VCAP::BigintMigration.opt_out?' do
    context 'when skip_bigint_id_migration is false' do
      let(:skip_bigint_id_migration) { false }

      it 'returns false' do
        expect(VCAP::BigintMigration.opt_out?).to be(false)
      end
    end

    context 'when skip_bigint_id_migration is true' do
      let(:skip_bigint_id_migration) { true }

      it 'returns true' do
        expect(VCAP::BigintMigration.opt_out?).to be(true)
      end
    end

    context 'when skip_bigint_id_migration is nil' do
      let(:skip_bigint_id_migration) { nil }

      it 'returns false' do
        expect(VCAP::BigintMigration.opt_out?).to be(false)
      end
    end

    context 'when raising InvalidConfigPath error' do
      before do
        allow_any_instance_of(VCAP::CloudController::Config).to receive(:get).with(:skip_bigint_id_migration).and_raise(VCAP::CloudController::Config::InvalidConfigPath)
      end

      it 'returns false' do
        expect(VCAP::BigintMigration.opt_out?).to be(false)
      end
    end
  end
end
