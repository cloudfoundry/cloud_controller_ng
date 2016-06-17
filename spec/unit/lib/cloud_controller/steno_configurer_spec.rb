require 'spec_helper'

module VCAP::CloudController
  RSpec.describe StenoConfigurer do
    let(:config_hash) { { level: 'debug2' } }
    subject(:configurer) { StenoConfigurer.new(config_hash) }

    before do
      allow(Steno).to receive(:init)
    end

    describe '.new' do
      it 'accepts a nil' do
        expect { StenoConfigurer.new(nil) }.not_to raise_error
      end
    end

    describe '#configure' do
      before do
        allow(Steno::Config).to receive(:new).and_call_original
        allow(Steno::Config).to receive(:to_config_hash).and_call_original
      end

      it 'calls Steno.init with the desired Steno config' do
        steno_config_hash = {}
        steno_config = double('Steno::Config')
        allow(Steno::Config).to receive(:to_config_hash).and_return(steno_config_hash)
        allow(Steno::Config).to receive(:new).and_return(steno_config)

        configurer.configure

        expect(Steno::Config).to have_received(:to_config_hash).with(config_hash)
        expect(Steno::Config).to have_received(:new).with(steno_config_hash)
        expect(Steno).to have_received(:init).with(steno_config)
      end

      it 'yields the properly configured Steno config hash to a block if provided' do
        block_called = false

        configurer.configure do |steno_config_hash|
          block_called = true
          expect(steno_config_hash.fetch(:context)).to be_a Steno::Context::ThreadLocal
          expect(steno_config_hash.fetch(:default_log_level)).to eq :debug2
        end

        expect(block_called).to be true
      end
    end
  end
end
