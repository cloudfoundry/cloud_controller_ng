require 'spec_helper'

RSpec.describe BackgroundJobEnvironment do
  before do
    allow(Steno).to receive(:init)
    TestConfig.override(
      db: 'cc-db',
      logging: { level: 'debug2' },
      bits_service: { enabled: false },
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

    it 'configures app observer with null stager and dea pool' do
      expect(VCAP::CloudController::AppObserver).to receive(:configure).with(
        instance_of(VCAP::CloudController::Stagers),
        instance_of(VCAP::CloudController::Runners)
      )
      background_job_environment.setup_environment
    end
  end
end
