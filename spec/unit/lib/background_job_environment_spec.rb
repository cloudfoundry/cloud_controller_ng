require 'spec_helper'

RSpec.describe BackgroundJobEnvironment do
  before do
    allow(Steno).to receive(:init)
    TestConfig.override(
      logging: { level: 'debug2' },
      bits_service: { enabled: false },
    )
  end
  let(:config) { TestConfig.config_instance }

  subject(:background_job_environment) { BackgroundJobEnvironment.new(config) }

  describe '#setup_environment' do
    before do
      allow(VCAP::CloudController::DB).to receive(:load_models)
      allow(Thread).to receive(:new).and_yield
      allow(EM).to receive(:run).and_yield
      allow(VCAP::CloudController::ResourcePool).to receive(:new)
      TestConfig.context = :worker
      TestConfig.override(readiness_port: 9999)
    end

    it 'loads models' do
      expect(VCAP::CloudController::DB).to receive(:load_models)
      background_job_environment.setup_environment
    end

    it 'opens the readiness port' do
      expect { TCPSocket.new('localhost', 9999).close }.to raise_error(Errno::ECONNREFUSED)
      background_job_environment.setup_environment
      expect { TCPSocket.new('localhost', 9999).close }.not_to raise_error
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
  end
end
