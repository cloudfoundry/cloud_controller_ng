require "spec_helper"

describe BackgroundJobEnvironment do
  let(:bg_config) { { db: "cc-db", logging: { level: 'debug2' } } }
  subject(:background_job_environment) { described_class.new(bg_config) }

  before do
    allow(Steno).to receive(:init)
  end

  describe "#setup_environment" do
    let(:message_bus) { double(:message_bus) }
    let(:message_bus_configurer) { double(MessageBus::Configurer, go: message_bus)}

    before do
      MessageBus::Configurer.stub(:new).and_return(message_bus_configurer)
      allow(VCAP::CloudController::DB).to receive(:load_models)
      Thread.stub(:new).and_yield
      EM.stub(:run).and_yield
    end

    it "loads models" do
      expect(VCAP::CloudController::DB).to receive(:load_models)
      background_job_environment.setup_environment
    end

    it "configures components" do
      expect(VCAP::CloudController::Config).to receive(:configure_components)
      background_job_environment.setup_environment
    end

    it "configures app observer with null stager and dea pool" do
      expect(VCAP::CloudController::AppObserver).to receive(:configure).with(
        bg_config,
        message_bus,
        instance_of(Object),
        instance_of(Object),
        instance_of(Object))
      background_job_environment.setup_environment
    end
  end
end