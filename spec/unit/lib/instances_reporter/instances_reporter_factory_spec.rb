require 'spec_helper'

module VCAP::CloudController::InstancesReporter
  describe InstancesReporterFactory do
    subject { described_class.new(diego_client, health_manager_client) }
    let(:app) { VCAP::CloudController::AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }
    let(:diego_client) { double(:diego_client) }
    let(:health_manager_client) { double(:health_manager_client) }

    let(:is_diego_app) { true }

    before do
      allow(diego_client).to receive(:running_enabled).and_return(is_diego_app)
    end

    context 'when building a reporter for a diego app' do
      let(:is_diego_app) { true }

      it 'returns a correctly configured DiegoInstancesReporter' do
        reporter = subject.instances_reporter_for_app(app)

        expect(reporter).to be_an_instance_of(DiegoInstancesReporter)
        expect(reporter.diego_client).to eq(diego_client)

        expect(diego_client).to have_received(:running_enabled).with(app)
      end
    end

    context 'when building a reporter for a legacy app' do
      let(:is_diego_app) { false }

      it 'returns a correctly configured LegacyInstancesReporter' do
        reporter = subject.instances_reporter_for_app(app)

        expect(reporter).to be_an_instance_of(LegacyInstancesReporter)
        expect(reporter.health_manager_client).to eq(health_manager_client)

        expect(diego_client).to have_received(:running_enabled).with(app)
      end
    end
  end
end