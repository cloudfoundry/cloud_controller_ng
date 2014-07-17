require 'spec_helper'

module VCAP::CloudController::InstancesReporter
  describe CompositeInstancesReporter do
    subject { described_class.new(diego_client, health_manager_client) }
    let(:diego_client) { double(:diego_client) }
    let(:health_manager_client) { double(:health_manager_client) }
    let(:legacy_reporter) { instance_double(LegacyInstancesReporter) }
    let(:diego_reporter) { instance_double(DiegoInstancesReporter) }

    before do
      allow(LegacyInstancesReporter).to receive(:new).and_return(legacy_reporter)
      allow(DiegoInstancesReporter).to receive(:new).and_return(diego_reporter)
    end

    let(:app) { VCAP::CloudController::AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }
    let(:is_diego_app) { true }

    before do
      allow(diego_client).to receive(:running_enabled).and_return(is_diego_app)
    end

    describe 'single app operations' do
      context 'with a legacy app' do
        let(:is_diego_app) { false }

        it 'uses the legacy reporter' do
          expect(legacy_reporter).to receive(:number_of_starting_and_running_instances_for_app).with(app)
          subject.number_of_starting_and_running_instances_for_app(app)

          expect(legacy_reporter).to receive(:all_instances_for_app).with(app)
          subject.all_instances_for_app(app)

          expect(legacy_reporter).to receive(:crashed_instances_for_app).with(app)
          subject.crashed_instances_for_app(app)

          expect(legacy_reporter).to receive(:stats_for_app).with(app)
          subject.stats_for_app(app)
        end
      end

      context 'with a diego app' do
        let(:is_diego_app) { true }

        it 'uses the diego reporter' do
          expect(diego_reporter).to receive(:number_of_starting_and_running_instances_for_app).with(app)
          subject.number_of_starting_and_running_instances_for_app(app)

          expect(diego_reporter).to receive(:all_instances_for_app).with(app)
          subject.all_instances_for_app(app)

          expect(diego_reporter).to receive(:crashed_instances_for_app).with(app)
          subject.crashed_instances_for_app(app)

          expect(diego_reporter).to receive(:stats_for_app).with(app)
          subject.stats_for_app(app)
        end
      end
    end

    describe 'bulk app operations' do
      context 'only legacy apps' do
        let(:is_diego_app) { false }

        it 'returns a hash using legacy reporter' do
          expect(legacy_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([app]).and_return({})
          allow(diego_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([]).and_return({})

          subject.number_of_starting_and_running_instances_for_apps([app])
        end
      end

      context 'only diego apps' do
        let(:is_diego_app) { true }

        it 'returns a hash using legacy reporter' do
          expect(diego_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([app]).and_return({})
          allow(legacy_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([]).and_return({})

          subject.number_of_starting_and_running_instances_for_apps([app])
        end
      end

      context 'a mix of legacy and diego apps' do
        let(:apps) do
          3.times.map { VCAP::CloudController::AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }
        end

        let(:diego_report) do
          { apps[0] => 2, apps[2] => 5 }
        end

        let(:legacy_report) do
          { apps[1] => 7 }
        end

        before do
          allow(diego_client).to receive(:running_enabled) { |app| app != apps[1] }
        end

        it 'associates the apps with the correct client' do
          expect(diego_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([apps[0], apps[2]])
                                    .and_return(diego_report)
          allow(legacy_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([apps[1]])
                                    .and_return(legacy_report)

          expect(subject.number_of_starting_and_running_instances_for_apps(apps)).to eql({
            apps[0] => 2,
            apps[1] => 7,
            apps[2] => 5,
          })
        end
      end
    end
  end
end
