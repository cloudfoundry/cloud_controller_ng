require 'spec_helper'

module VCAP::CloudController
  describe InstancesReporters do
    let(:config) do
      {
        diego: {
          staging: 'optional',
          running: 'optional',
        },
        diego_docker: true
      }
    end

    let(:diego_client) { instance_double(Diego::Client) }
    let(:hm_client) { instance_double(Dea::HM9000::Client) }

    let(:dea_app) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }
    let(:diego_app) do
      AppFactory.make(
        package_hash: 'abc',
        package_state: 'STAGED',
        environment_json: { 'DIEGO_RUN_BETA' => 'true' }
      )
    end

    let(:reporter) { double(:Reporter) }
    let(:reporter2) { double(:Reporter) }
    let(:instances_reporters) { InstancesReporters.new(config, diego_client, hm_client) }

    describe '#number_of_starting_and_running_instances_for_app' do
      it 'delegates to the reporter' do
        allow(Dea::InstancesReporter).to receive(:new).with(hm_client).and_return(reporter)
        allow(reporter).to receive(:number_of_starting_and_running_instances_for_app).with(dea_app).and_return(1)

        expect(instances_reporters.number_of_starting_and_running_instances_for_app(dea_app)).to eq(1)
      end
    end

    describe '#all_instances_for_app' do
      it 'delegates to the reporter' do
        allow(Diego::InstancesReporter).to receive(:new).with(diego_client).and_return(reporter)
        expect(reporter).to receive(:all_instances_for_app).with(diego_app).and_return(2)

        expect(instances_reporters.all_instances_for_app(diego_app)).to eq(2)
      end
    end

    describe '#crashed_instances_for_app' do
      it 'delegates to the reporter' do
        allow(instances_reporters).to receive(:diego_running_disabled?).and_return(true)
        allow(Dea::InstancesReporter).to receive(:new).with(hm_client).and_return(reporter)
        expect(reporter).to receive(:crashed_instances_for_app).with(diego_app).and_return(3)

        expect(instances_reporters.crashed_instances_for_app(diego_app)).to eq(3)
      end
    end

    describe '#stats_for_app' do
      it 'delegates to the reporter' do
        allow(Dea::InstancesReporter).to receive(:new).with(hm_client).and_return(reporter)
        expect(reporter).to receive(:stats_for_app).with(dea_app).and_return(1 => {})

        expect(instances_reporters.stats_for_app(dea_app)).to eq(1 => {})
      end
    end

    describe '#number_of_starting_and_running_instances_for_apps' do
      let(:apps) { [dea_app, diego_app] }

      before do
        allow(Dea::InstancesReporter).to receive(:new).with(hm_client).and_return(reporter)
        allow(Diego::InstancesReporter).to receive(:new).with(diego_client).and_return(reporter2)
      end

      context 'when diego running is enabled' do
        it 'delegates to the proper reporter' do
          expect(reporter).to receive(:number_of_starting_and_running_instances_for_apps).
            with([dea_app]).and_return({ 1 => {} })
          expect(reporter2).to receive(:number_of_starting_and_running_instances_for_apps).
            with([diego_app]).and_return({ 2 => {} })
          expect(instances_reporters.number_of_starting_and_running_instances_for_apps(apps)).
            to eq({ 1 => {}, 2 => {} })
        end
      end

      context 'when diego running is disabled' do
        before do
          config[:diego][:running] = 'disabled'
        end

        it 'delegates to the proper reporter' do
          expect(reporter).to receive(:number_of_starting_and_running_instances_for_apps).
            with([dea_app, diego_app]).and_return({ 1 => {}, 3 => {} })
          expect(reporter2).to receive(:number_of_starting_and_running_instances_for_apps).
            with([]).and_return({})
          expect(instances_reporters.number_of_starting_and_running_instances_for_apps(apps)).
            to eq({ 1 => {}, 3 => {} })
        end
      end
    end
  end
end
