require 'spec_helper'

module VCAP::CloudController
  describe Dea::InstancesReporter do
    subject { described_class.new(health_manager_client) }
    let(:app) { AppFactory.make(:package_hash => "abc", :package_state => "STAGED") }
    let(:health_manager_client) { double(:health_manager_client) }

    describe '#all_instances_for_app' do
      let(:instances) do
        {
          0 => {
            :state => 'RUNNING',
            :since => 1,
          },
        }
      end

      before do
        allow(Dea::Client).to receive(:find_all_instances).and_return(instances)
      end

      it 'uses Dea::Client to return instances' do
        response = subject.all_instances_for_app(app)

        expect(Dea::Client).to have_received(:find_all_instances).with(app)
        expect(instances).to eq(response)
      end
    end

    describe '#number_of_starting_and_running_instances_for_app' do
      context 'when the app is not started' do
        before do
          app.state = 'STOPPED'
        end

        it 'returns 0' do
          result = subject.number_of_starting_and_running_instances_for_app(app)

          expect(result).to eq(0)
        end
      end

      context 'when the app is started' do
        before do
          app.state = 'STARTED'
          allow(health_manager_client).to receive(:healthy_instances).and_return(5)
        end

        it 'asks the health manager for the number of healthy_instances and returns that' do
          result = subject.number_of_starting_and_running_instances_for_app(app)

          expect(health_manager_client).to have_received(:healthy_instances).with(app)
          expect(result).to eq(5)
        end
      end
    end

    describe '#number_of_starting_and_running_instances_for_apps' do
      let(:running_apps) do
        3.times.map do
          AppFactory.make(:state => "STARTED", :package_state => "STAGED", :package_hash => "abc")
        end
      end

      let(:stopped_apps) do
        3.times.map do
          AppFactory.make(:state => "STOPPED", :package_state => "STAGED", :package_hash => "xyz")
        end
      end

      let(:apps) { running_apps + stopped_apps }

      describe 'stopped apps' do
        before do
          allow(health_manager_client).to receive(:healthy_instances_bulk) do |args|
            stopped_apps.each { |stopped| expect(args).not_to include(stopped) }
            {}
          end
        end

        it 'should not ask the health manager about active instances for stopped apps' do
          subject.number_of_starting_and_running_instances_for_apps(stopped_apps)
        end

        it 'should return 0 instances for apps that are stopped' do
          result = subject.number_of_starting_and_running_instances_for_apps(stopped_apps)
          expect(result.length).to be(3)
          stopped_apps.each { |app| expect(result[app.guid]).to eq(0) }
        end
      end

      describe 'running apps' do
        before do
          allow(health_manager_client).to receive(:healthy_instances_bulk) do |apps|
            apps.reduce({}) do |hash, app|
              hash[app.guid] = 3
              hash
            end
          end
        end

        it 'should ask the health manager for active instances for running apps' do
          expect(health_manager_client).to receive(:healthy_instances_bulk).with(running_apps)

          result = subject.number_of_starting_and_running_instances_for_apps(running_apps)
          expect(result.length).to be(3)
          running_apps.each { |app| expect(result[app.guid]).to eq(3) }
        end
      end
    end

    describe '#crashed_instances_for_app' do
      before do
        allow(health_manager_client).to receive(:find_crashes).and_return('some return value')
      end

      it 'asks the health manager for the crashed instances and returns that' do
        result = subject.crashed_instances_for_app(app)

        expect(health_manager_client).to have_received(:find_crashes).with(app)
        expect(result).to eq('some return value')
      end
    end

    describe '#stats_for_app' do

      before do
        allow(Dea::Client).to receive(:find_stats).and_return('some return value')
      end

      it 'uses Dea::Client to return stats' do
        result = subject.stats_for_app(app)

        expect(Dea::Client).to have_received(:find_stats).with(app)
        expect(result).to eq('some return value')
      end
    end
  end
end
