require 'spec_helper'

RSpec.describe BackgroundJobEnvironment do
  subject(:background_job_environment) { BackgroundJobEnvironment.new(config) }

  before do
    allow(Steno).to receive(:init)

    TestConfig.override(
      logging: { level: 'fatal' }
    )
  end

  let(:config) { VCAP::CloudController::Config.config }

  describe '#setup_environment' do
    before do
      allow(VCAP::CloudController::DB).to receive(:load_models)
      allow(VCAP::CloudController::ResourcePool).to receive(:new)
    end

    it 'loads models' do
      expect(VCAP::CloudController::DB).to receive(:load_models)
      background_job_environment.setup_environment
    end

    it 'configures components' do
      expect(config).to receive(:configure_components)
      background_job_environment.setup_environment
    end

    it 'configures app observer with null stager and runner' do
      expect(VCAP::CloudController::ProcessObserver).to receive(:configure).with(
        instance_of(VCAP::CloudController::Stagers),
        instance_of(VCAP::CloudController::Runners)
      )
      background_job_environment.setup_environment
    end

    def open_port_count
      `lsof -i -P -n | grep LISTEN | grep #{Process.pid} | wc -l`.to_i
    end

    it 'doesnt attempt to open a readiness port' do
      expect do
        background_job_environment.setup_environment
      end.not_to(change { open_port_count })
    end

    context 'readiness_port provided' do
      it 'opens the readiness port' do
        expect { TCPSocket.new('127.0.0.1', 9999).close }.to raise_error(Errno::ECONNREFUSED)
        expect do
          background_job_environment.setup_environment(9999)
        end.to change { open_port_count }.by(1)
        expect { background_job_environment.readiness_server.close }.not_to raise_error
      end
    end
  end
end
