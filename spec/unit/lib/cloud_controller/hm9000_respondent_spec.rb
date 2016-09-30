require 'spec_helper'
require 'cloud_controller/dea/hm9000/respondent'

module VCAP::CloudController
  RSpec.describe Dea::HM9000::Respondent do
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:dea_client) { double('dea client', message_bus: message_bus) }

    subject { Dea::HM9000::Respondent.new(dea_client, message_bus) }

    let(:app_starter_task) { instance_double(Dea::AppStarterTask, start: nil) }
    let(:config) { TestConfig.config }

    before do
      allow(Dea::AppStarterTask).to receive(:new).and_return(app_starter_task)
      allow(dea_client).to receive(:stop_instances)
      allow(dea_client).to receive(:start_instances)
      allow(dea_client).to receive(:config).and_return(config)
    end

    describe '#handle_requests' do
      before { allow(message_bus).to receive(:subscribe) }

      it 'subscribes hm9000.stop and sets up callback to process_hm9000_stop' do
        expect(message_bus).to receive(:subscribe).with('hm9000.stop', queue: 'cc') do |&callback|
          callback.call('some payload')
        end

        expect(subject).to receive(:process_hm9000_stop).with('some payload')

        subject.handle_requests
      end

      it 'subscribes hm9000.start and sets up callback to process_hm9000_start' do
        expect(message_bus).to receive(:subscribe).with('hm9000.start', queue: 'cc') do |&callback|
          callback.call('some payload')
        end

        expect(subject).to receive(:process_hm9000_start).with('some payload')

        subject.handle_requests
      end
    end

    let(:app) do
      AppFactory.make(
        instances: 2,
        state: app_state,
        diego: diego,
      )
    end
    let(:diego) { false }
    let(:app_state) { 'STARTED' }

    describe '#process_hm9000_start' do
      let(:hm9000_start_message) do
        { 'droplet' => start_droplet,
          'version' => start_version,
          'instance_index' => start_instance_index,
          'message_id' => 'abc'
        }
      end

      context 'when the message is missing fields' do
        it 'should not do anything' do
          expect(dea_client).not_to receive(:start_instances)
          subject.process_hm9000_stop({ 'droplet' => app.guid, 'instance_index' => 2 })
        end
      end

      context 'if the app does not exist' do
        let(:start_droplet) { 'a-non-existent-app' }
        let(:start_version) { app.version }
        let(:start_instance_index) { 1 }

        it 'should not do anything' do
          expect(dea_client).not_to receive(:start_instances)
          subject.process_hm9000_start(hm9000_start_message)
        end
      end

      context 'if the app does exit' do
        let(:start_droplet) { app.guid }

        context 'if the version matches' do
          let(:start_version) { app.version }
          context 'if the desired index is within the desired number of instances' do
            let(:start_instance_index) { 1 }
            context 'if app is in STARTED state' do
              context 'and the diego flag is set' do
                let(:diego) { true }

                it 'should not send the start message' do
                  expect(dea_client).not_to receive(:start_instances)
                  subject.process_hm9000_start(hm9000_start_message)
                end
              end

              context 'and the diego flag is not set' do
                it 'should send the start message' do
                  expect(app_starter_task).to receive(:start).with(specific_instances: 1)

                  subject.process_hm9000_start(hm9000_start_message)
                end
              end
            end

            context 'if the app has not finished uploading' do
              let(:droplet_hash) { nil }

              it 'should not do anything' do
                expect(dea_client).not_to receive(:start_instances)
                subject.process_hm9000_start(hm9000_start_message)
              end
            end

            context 'if the app failed to stage' do
              before do
                DropletModel.make(app: app.app, package: app.latest_package, state: DropletModel::FAILED_STATE)
                app.reload
              end

              it 'should not do anything' do
                expect(dea_client).not_to receive(:start_instances)
                subject.process_hm9000_start(hm9000_start_message)
              end
            end

            context 'if app is NOT in STARTED state' do
              let(:app_state) { 'STOPPED' }

              it 'should not do anything' do
                expect(dea_client).not_to receive(:start_instances)
                subject.process_hm9000_start(hm9000_start_message)
              end
            end
          end

          context 'if the desired index is outside the desired number of instances' do
            let(:start_instance_index) { 2 }

            it 'should not do anything' do
              expect(dea_client).not_to receive(:start_instances)
              subject.process_hm9000_start(hm9000_start_message)
            end
          end
        end

        context 'if the version does not match' do
          let(:start_version) { 'another-version' }
          let(:start_instance_index) { 1 }

          it 'should not do anything' do
            expect(dea_client).not_to receive(:start_instances)
            subject.process_hm9000_start(hm9000_start_message)
          end
        end
      end
    end

    describe '#process_hm9000_stop' do
      let(:hm9000_stop_message) do
        { 'droplet' => stop_droplet,
          'version' => stop_version,
          'instance_guid' => 'abc',
          'instance_index' => stop_instance_index,
          'is_duplicate' => is_duplicate,
          'message_id' => 'abc'
        }
      end

      let(:is_duplicate) { false }

      context 'when the message is missing fields' do
        it 'should not do anything' do
          expect(dea_client).not_to receive(:stop_instances)
          subject.process_hm9000_stop({ 'droplet' => app.guid, 'instance_guid' => 'abc' })
        end
      end

      context 'when the app does not exist' do
        let(:stop_droplet) { 'a-non-existent-app' }
        let(:stop_version) { 'current-version' }
        let(:stop_instance_index) { 1 }

        it 'should stop the instance' do
          expect(dea_client).to receive(:stop_instances) do |app_guid_to_stop, guid|
            expect(app_guid_to_stop).to eq('a-non-existent-app')
            expect(guid).to eq('abc')
          end

          subject.process_hm9000_stop(hm9000_stop_message)
        end
      end

      context 'when the app exists' do
        let(:stop_droplet) { app.guid }

        context 'and the currently-running version of the app matches the version in the stop message' do
          let(:stop_version) { app.version }

          context 'when the index to stop is outside the range of desired indices' do
            let(:stop_instance_index) { 2 }
            it 'should stop the instance' do
              expect(dea_client).to receive(:stop_instances) do |app_guid_to_stop, guid|
                expect(app_guid_to_stop).to eq(app.guid)
                expect(guid).to eq('abc')
              end

              subject.process_hm9000_stop(hm9000_stop_message)
            end
          end

          context 'when the index to stop is within the range of desired indices' do
            let(:stop_instance_index) { 1 }

            context 'and the instance is a duplicate (there is > 1 running on that index)' do
              let(:is_duplicate) { true }
              it 'should stop the index' do
                expect(dea_client).to receive(:stop_instances) do |app_guid_to_stop, guid|
                  expect(app_guid_to_stop).to eq(app.guid)
                  expect(guid).to eq('abc')
                end

                subject.process_hm9000_stop(hm9000_stop_message)
              end
            end

            context 'and the instance is not a duplicate (there is only 1 running on that index)' do
              context 'and the app is in the STARTED state' do
                context 'and the package has staged' do
                  it 'should ignore the request' do
                    expect(dea_client).not_to receive(:stop_instances)
                    subject.process_hm9000_stop(hm9000_stop_message)
                  end
                end

                context 'but the package is staging' do
                  before do
                    DropletModel.make(app: app.app, package: app.latest_package, state: DropletModel::STAGING_STATE)
                    app.reload
                  end

                  it 'should ignore the request' do
                    expect(dea_client).not_to receive(:stop_instances)
                    subject.process_hm9000_stop(hm9000_stop_message)
                  end
                end

                context 'but the package has failed to stage' do
                  before do
                    DropletModel.make(app: app.app, package: app.latest_package, state: DropletModel::FAILED_STATE)
                    app.reload
                  end

                  it 'should stop the index' do
                    expect(dea_client).to receive(:stop_instances) do |app_guid_to_stop, guid|
                      expect(app_guid_to_stop).to eq(app.guid)
                      expect(guid).to eq('abc')
                    end

                    subject.process_hm9000_stop(hm9000_stop_message)
                  end
                end
              end

              context 'and the app is in the STOPPED state' do
                let(:app_state) { 'STOPPED' }

                it 'should stop the instance' do
                  expect(dea_client).to receive(:stop_instances) do |app_guid_to_stop, guid|
                    expect(app_guid_to_stop).to eq(app.guid)
                    expect(guid).to eq('abc')
                  end

                  subject.process_hm9000_stop(hm9000_stop_message)
                end
              end
            end

            context 'and the diego flag is set ' do
              let(:diego) { true }

              it 'should stop the instance' do
                expect(dea_client).to receive(:stop_instances) do |app_guid_to_stop, guid|
                  expect(app_guid_to_stop).to eq(app.guid)
                  expect(guid).to eq('abc')
                end

                subject.process_hm9000_stop(hm9000_stop_message)
              end
            end
          end
        end

        context 'and the currently-running version of the app is different from the version in the stop message' do
          let(:stop_version) { 'different-version' }
          let(:stop_instance_index) { 1 }

          it 'should stop the instance' do
            expect(dea_client).to receive(:stop_instances) do |app_guid_to_stop, guid|
              expect(app_guid_to_stop).to eq(app.guid)
              expect(guid).to eq('abc')
            end

            subject.process_hm9000_stop(hm9000_stop_message)
          end
        end
      end
    end
  end
end
