require 'spec_helper'

module VCAP::CloudController
  describe CompositeInstancesReporter do
    subject { described_class.new(diego_client, health_manager_client) }
    let(:diego_client) { double(:diego_client) }
    let(:health_manager_client) { double(:health_manager_client) }
    let(:dea_reporter) { instance_double(Dea::InstancesReporter) }
    let(:diego_reporter) { instance_double(Diego::InstancesReporter) }

    before do
      allow(Dea::InstancesReporter).to receive(:new).and_return(dea_reporter)
      allow(Diego::InstancesReporter).to receive(:new).and_return(diego_reporter)
    end

    let(:app) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }


    describe 'single app operations' do
      context 'with a legacy app' do
        it 'uses the legacy reporter' do
          expect(dea_reporter).to receive(:number_of_starting_and_running_instances_for_app).with(app)
          subject.number_of_starting_and_running_instances_for_app(app)

          expect(dea_reporter).to receive(:all_instances_for_app).with(app)
          subject.all_instances_for_app(app)

          expect(dea_reporter).to receive(:crashed_instances_for_app).with(app)
          subject.crashed_instances_for_app(app)

          expect(dea_reporter).to receive(:stats_for_app).with(app)
          subject.stats_for_app(app)
        end
      end

      context 'with a diego app' do
        before do
          app.environment_json = {"CF_DIEGO_RUN_BETA" => "true"}
        end

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
        it 'returns a hash using legacy reporter' do
          expect(dea_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([app]).and_return({})
          allow(diego_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([]).and_return({})

          subject.number_of_starting_and_running_instances_for_apps([app])
        end
      end

      context 'only diego apps' do
        before do
          app.environment_json = {"CF_DIEGO_RUN_BETA" => "true"}
        end

        it 'returns a hash using legacy reporter' do
          expect(diego_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([app]).and_return({})
          allow(dea_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([]).and_return({})

          subject.number_of_starting_and_running_instances_for_apps([app])
        end
      end

      context 'a mix of legacy and diego apps' do
        let(:apps) do
            [
              AppFactory.make(package_hash: 'abc', package_state: 'STAGED', environment_json: {"CF_DIEGO_RUN_BETA" => "true"}),
              AppFactory.make(package_hash: 'abc', package_state: 'STAGED'),
              AppFactory.make(package_hash: 'abc', package_state: 'STAGED', environment_json: {"CF_DIEGO_RUN_BETA" => "true"}),
          ]
        end

        let(:diego_report) do
          {apps[0] => 2, apps[2] => 5}
        end

        let(:legacy_report) do
          {apps[1] => 7}
        end

        it 'associates the apps with the correct client' do
          expect(diego_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([apps[0], apps[2]])
                                    .and_return(diego_report)
          allow(dea_reporter).to receive(:number_of_starting_and_running_instances_for_apps).with([apps[1]])
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
