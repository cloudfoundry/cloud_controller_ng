require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Dea::InstancesReporter do
    subject { described_class.new(health_manager_client) }
    let(:app) { AppFactory.make }
    let(:health_manager_client) { double(:health_manager_client) }

    describe '#all_instances_for_app' do
      let(:instances) do
        {
          0 => {
            state: 'RUNNING',
            since: 1,
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

    describe '#number_of_starting_and_running_instances_for_process' do
      context 'when the app is not started' do
        before do
          app.state = 'STOPPED'
        end

        it 'returns 0' do
          result = subject.number_of_starting_and_running_instances_for_process(app)

          expect(result).to eq(0)
        end
      end

      context 'when the app is started' do
        before do
          app.state = 'STARTED'
          allow(health_manager_client).to receive(:healthy_instances).and_return(5)
        end

        it 'asks the health manager for the number of healthy_instances and returns that' do
          result = subject.number_of_starting_and_running_instances_for_process(app)

          expect(health_manager_client).to have_received(:healthy_instances).with(app)
          expect(result).to eq(5)
        end

        context 'and the app failed to stage' do
          before do
            app.latest_package.update(state: 'FAILED')
          end

          it 'returns 0' do
            result = subject.number_of_starting_and_running_instances_for_process(app)

            expect(result).to eq(0)
          end
        end
      end
    end

    describe '#number_of_starting_and_running_instances_for_processes' do
      let(:running_apps) do
        Array.new(3) do
          AppFactory.make(state: 'STARTED')
        end
      end

      let(:stopped_apps) do
        Array.new(3) do
          AppFactory.make(state: 'STOPPED')
        end
      end

      let(:failed_apps) do
        a = AppFactory.make(state: 'STARTED')
        a.latest_package.update(state: 'FAILED')
        [a]
      end

      let(:pending_apps) do
        [App.make(state: 'STARTED')]
      end

      let(:apps) { running_apps + stopped_apps + failed_apps + pending_apps }

      describe 'stopped apps' do
        before do
          allow(health_manager_client).to receive(:healthy_instances_bulk) do |args|
            stopped_apps.each { |stopped| expect(args).not_to include(stopped) }
            {}
          end
        end

        it 'should not ask the health manager about active instances for stopped apps' do
          subject.number_of_starting_and_running_instances_for_processes(stopped_apps)
        end

        it 'should return 0 instances for apps that are stopped' do
          result = subject.number_of_starting_and_running_instances_for_processes(stopped_apps)
          expect(result.length).to be(3)
          stopped_apps.each { |app| expect(result[app.guid]).to eq(0) }
        end
      end

      describe 'failed apps' do
        before do
          allow(health_manager_client).to receive(:healthy_instances_bulk) do |args|
            failed_apps.each { |failed| expect(args).not_to include(failed) }
            {}
          end
        end

        it 'should not ask the health manager about active instances for failed apps' do
          subject.number_of_starting_and_running_instances_for_processes(failed_apps)
        end

        it 'should return 0 instances for apps that are failed' do
          result = subject.number_of_starting_and_running_instances_for_processes(failed_apps)
          expect(result.length).to be(1)
          failed_apps.each { |app| expect(result[app.guid]).to eq(0) }
        end
      end

      describe 'pending apps' do
        before do
          allow(health_manager_client).to receive(:healthy_instances_bulk) do |args|
            pending_apps.each { |pending| expect(args).not_to include(pending) }
            {}
          end
        end

        it 'should not ask the health manager about active instances for pending apps' do
          subject.number_of_starting_and_running_instances_for_processes(pending_apps)
        end

        it 'should return 0 instances for apps that are pending' do
          result = subject.number_of_starting_and_running_instances_for_processes(pending_apps)
          expect(result.length).to be(1)
          pending_apps.each { |app| expect(result[app.guid]).to eq(0) }
        end
      end

      describe 'running apps' do
        before do
          allow(health_manager_client).to receive(:healthy_instances_bulk) do |apps|
            apps.each_with_object({}) do |app, hash|
              hash[app.guid] = 3
            end
          end
        end

        it 'should ask the health manager for active instances for running apps' do
          expect(health_manager_client).to receive(:healthy_instances_bulk).with(running_apps)

          result = subject.number_of_starting_and_running_instances_for_processes(running_apps)
          expect(result.length).to be(3)
          running_apps.each { |app| expect(result[app.guid]).to eq(3) }
        end
      end

      describe 'started apps that failed to stage' do
        let(:staging_failed_apps) do
          Array.new(3) do
            AppFactory.make(state: 'STARTED').tap do |a|
              a.latest_package.update(state: 'FAILED')
            end
          end
        end
        before do
        end

        it 'should return 0 instances for apps that failed to stage' do
          expect(health_manager_client).not_to receive(:healthy_instances_bulk)

          result = subject.number_of_starting_and_running_instances_for_processes(staging_failed_apps)
          expect(result.length).to be(3)
          staging_failed_apps.each { |app| expect(result[app.guid]).to eq(0) }
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
