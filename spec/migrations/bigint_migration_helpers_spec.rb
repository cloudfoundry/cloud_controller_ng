require 'spec_helper'
require_relative '../../db/helpers/bigint_migration'

RSpec.describe 'bigint migration helpers', isolation: :truncation, type: :migration do
  let(:fake_config) { double }
  let(:skip_bigint_id_migration) { nil }

  before do
    allow(fake_config).to receive(:get).with(:skip_bigint_id_migration).and_return(skip_bigint_id_migration)
    allow(RakeConfig).to receive(:config).and_return(fake_config)
  end

  describe '#opt_out?' do
    context 'when skip_bigint_id_migration is false' do
      let(:skip_bigint_id_migration) { false }

      it 'returns false' do
        expect(opt_out?).to be(false)
      end
    end

    context 'when skip_bigint_id_migration is true' do
      let(:skip_bigint_id_migration) { true }

      it 'returns true' do
        expect(opt_out?).to be(true)
      end
    end

    context 'when skip_bigint_id_migration is nil' do
      let(:skip_bigint_id_migration) { nil }

      it 'returns false' do
        expect(opt_out?).to be(false)
      end
    end

    context 'when raising InvalidConfigPath error' do
      before do
        allow(fake_config).to receive(:get).with(:skip_bigint_id_migration).and_raise(VCAP::CloudController::Config::InvalidConfigPath)
      end

      it 'returns false' do
        expect(opt_out?).to be(false)
      end
    end
  end
end
