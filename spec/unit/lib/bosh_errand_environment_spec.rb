require 'spec_helper'

RSpec.describe BoshErrandEnvironment do
  let(:stdout_sink_enabled) { true }
  let(:config) { VCAP::CloudController::Config.new(
    {
      db: DbConfig.new.config,
      logging: { level: 'fatal', stdout_sink_enabled: stdout_sink_enabled }
    },
    context: :rotate_database_key)
  }

  subject(:bosh_errand_environment) { BoshErrandEnvironment.new(config) }

  describe '#initialize' do
    it 'configures steno logger with stdout sink' do
      bosh_errand_environment.setup_environment
      expect(Steno.logger('cc.errand').instance_variable_get(:@sinks).length).to be(2)
    end

    context 'when `stdout_sink_enabled` is `false`' do
      let(:stdout_sink_enabled) { false }

      it 'configures steno logger wo stdout sink' do
        bosh_errand_environment.setup_environment
        expect(Steno.logger('cc.errand').instance_variable_get(:@sinks).length).to be(1)
      end
    end
  end

  describe '#setup_environment' do
    before do
      allow(VCAP::CloudController::DB).to receive(:load_models)
    end

    it 'loads models' do
      expect(VCAP::CloudController::DB).to receive(:load_models)
      bosh_errand_environment.setup_environment
    end

    it 'configures components' do
      expect(config).to receive(:configure_components)
      bosh_errand_environment.setup_environment
    end
  end
end
