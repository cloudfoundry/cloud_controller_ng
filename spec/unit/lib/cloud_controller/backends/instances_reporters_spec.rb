require 'spec_helper'

module VCAP::CloudController
  describe InstancesReporters do
    let(:tps_client) { instance_double(Diego::TPSClient) }
    let(:hm_client) { instance_double(Dea::HM9000::Client) }

    let(:dea_app) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }
    let(:diego_app) do
      AppFactory.make(
          package_hash: 'abc',
          package_state: 'STAGED',
          diego: true
      )
    end

    let(:dea_reporter) { instance_double(Dea::InstancesReporter) }
    let(:diego_reporter) { instance_double(Diego::InstancesReporter) }
    let(:instances_reporters) { InstancesReporters.new(tps_client, hm_client) }

    before do
      allow(Dea::InstancesReporter).to receive(:new).with(hm_client).and_return(dea_reporter)
      allow(Diego::InstancesReporter).to receive(:new).with(tps_client).and_return(diego_reporter)
    end

    describe '#number_of_starting_and_running_instances_for_app' do
      context 'when the app is a DEA app' do
        it 'delegates to the DEA reporter' do
          allow(dea_reporter).to receive(:number_of_starting_and_running_instances_for_app).with(dea_app).and_return(1)

          expect(instances_reporters.number_of_starting_and_running_instances_for_app(dea_app)).to eq(1)
        end
      end

      context 'when the app is a Diego app' do
        it 'delegates to the Diego reporter' do
          allow(diego_reporter).to receive(:number_of_starting_and_running_instances_for_app).with(diego_app).and_return(2)

          expect(instances_reporters.number_of_starting_and_running_instances_for_app(diego_app)).to eq(2)
        end
      end
    end

    describe '#all_instances_for_app' do
      context 'when the app is a DEA app' do
        it 'delegates to the reporter' do
          expect(dea_reporter).to receive(:all_instances_for_app).with(dea_app).and_return(3)

          expect(instances_reporters.all_instances_for_app(dea_app)).to eq(3)
        end
      end

      context 'when the app is a Diego app' do
        it 'delegates to the reporter' do
          expect(diego_reporter).to receive(:all_instances_for_app).with(diego_app).and_return(4)

          expect(instances_reporters.all_instances_for_app(diego_app)).to eq(4)
        end
      end
    end

    describe '#crashed_instances_for_app' do
      context 'when the app is a DEA app' do
        it 'delegates to the reporter' do
          expect(dea_reporter).to receive(:crashed_instances_for_app).with(dea_app).and_return(5)

          expect(instances_reporters.crashed_instances_for_app(dea_app)).to eq(5)
        end
      end

      context 'when the app is a Diego app' do
        it 'delegates to the reporter' do
          expect(diego_reporter).to receive(:crashed_instances_for_app).with(diego_app).and_return(6)

          expect(instances_reporters.crashed_instances_for_app(diego_app)).to eq(6)
        end
      end
    end

    describe '#stats_for_app' do
      context 'when the app is a DEA app' do
        it 'delegates to the reporter' do
          expect(dea_reporter).to receive(:stats_for_app).with(dea_app).and_return(1 => {})

          expect(instances_reporters.stats_for_app(dea_app)).to eq(1 => {})
        end
      end

      context 'when the app is a Diego app' do
        it 'delegates to the reporter' do
          expect(diego_reporter).to receive(:stats_for_app).with(diego_app).and_return(2 => {})

          expect(instances_reporters.stats_for_app(diego_app)).to eq(2 => {})
        end
      end
    end

    describe '#number_of_starting_and_running_instances_for_apps' do
      let(:apps) { [dea_app, diego_app] }

      it 'delegates to the proper reporter' do
        expect(dea_reporter).to receive(:number_of_starting_and_running_instances_for_apps).
                                    with([dea_app]).and_return({ 1 => {} })
        expect(diego_reporter).to receive(:number_of_starting_and_running_instances_for_apps).
                                      with([diego_app]).and_return({ 2 => {} })
        expect(instances_reporters.number_of_starting_and_running_instances_for_apps(apps)).
            to eq({ 1 => {}, 2 => {} })
      end
    end
  end
end
