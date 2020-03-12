require 'spec_helper'

RSpec.describe BackgroundJobEnvironment do
  before do
    allow(Steno).to receive(:init)
    TestConfig.context = :worker
    TestConfig.override(
      logging: { level: 'debug2' },
      bits_service: { enabled: false },
      readiness_port: nil
    )
  end
  let(:config) { VCAP::CloudController::Config.config }

  subject(:background_job_environment) { BackgroundJobEnvironment.new(config) }

  describe '#setup_environment' do
    before do
      allow(VCAP::CloudController::DB).to receive(:load_models)
      allow(Thread).to receive(:new).and_yield
      allow(EM).to receive(:run).and_yield
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

    it 'doesnt attempt to open a readiness port' do
      expect { TCPSocket.new('localhost', 9999).close }.to raise_error(Errno::ECONNREFUSED)
      background_job_environment.setup_environment
      expect { TCPSocket.new('localhost', 9999).close }.to raise_error(Errno::ECONNREFUSED)
    end

    context 'readiness_port provided' do
      it 'opens the readiness port' do
        expect { TCPSocket.new('localhost', 9999).close }.to raise_error(Errno::ECONNREFUSED)
        background_job_environment.setup_environment(9999)
        expect { TCPSocket.new('localhost', 9999).close }.not_to raise_error
      end
    end
  end
end
