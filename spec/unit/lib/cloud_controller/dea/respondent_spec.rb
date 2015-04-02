require 'spec_helper'
require 'cloud_controller/dea/respondent'

module VCAP::CloudController
  describe Dea::Respondent do
    before { allow(message_bus).to receive(:subscribe).with(anything) }

    let(:message_bus) { double('message_bus') }

    let(:app) do
      AppFactory.make(
        instances: 2, state: 'STARTED', package_hash: 'SOME_HASH', package_state: 'STAGED'
      ).save
    end

    let(:droplet) { app.guid }
    let(:reason) { 'CRASHED' }
    let(:payload) do
      {
        'cc_partition' => 'cc_partition',
        'droplet' => droplet,
        'version' => app.version,
        'instance' => 'instance_id',
        'index' => 0,
        'reason' => reason,
        'exit_status' => 145,
        'exit_description' => 'Exit description',
      }
    end

    subject(:respondent) { Dea::Respondent.new(message_bus) }

    describe '#initialize' do
      it "sets logger to a Steno Logger with tag 'cc.dea_respondent'" do
        logger = respondent.logger
        expect(logger).to be_a_kind_of Steno::Logger
        expect(logger.name).to eq('cc.dea_respondent')
      end
    end

    describe '#start' do
      it "subscribes to 'droplet.exited' with a queue" do
        expect(message_bus).to receive(:subscribe).with('droplet.exited',
          queue: VCAP::CloudController::Dea::Respondent::CRASH_EVENT_QUEUE)

        respondent.start
      end
    end

    describe '#process_droplet_exited_message' do
      context 'when the app crashed' do
        context 'the app described in the event exists' do
          it 'adds a record in the Events table' do
            time = Time.new(1990, 07, 06)
            stub_const('Sequel::CURRENT_TIMESTAMP', time)
            respondent.process_droplet_exited_message(payload)

            app_event = Event.find(actee: app.guid)

            expect(app_event).to be
            expect(app_event.space).to eq(app.space)
            expect(app_event.type).to eq('app.crash')
            expect(app_event.timestamp.to_i).to eq(time.to_i)
            expect(app_event.actor_type).to eq('app')
            expect(app_event.actor).to eq(app.guid)
            expect(app_event.metadata['instance']).to eq(payload['instance'])
            expect(app_event.metadata['index']).to eq(payload['index'])
            expect(app_event.metadata['exit_status']).to eq(payload['exit_status'])
            expect(app_event.metadata['exit_description']).to eq(payload['exit_description'])
            expect(app_event.metadata['reason']).to eq(reason)
          end
        end

        context 'when the app is a process that belongs to a v3 app' do
          let(:app_model) { AppModel.make }

          before do
            app_model.add_process_by_guid(app.guid)
          end

          it 'adds a record in the events table' do
            time = Time.new(1990, 07, 06)
            stub_const('Sequel::CURRENT_TIMESTAMP', time)
            respondent.process_droplet_exited_message(payload)

            v3event = Event.last
            expect(v3event.type).to eq('app.process.crash')
            expect(v3event.actor).to eq(app.guid)
            expect(v3event.actor_type).to eq('process')
            expect(v3event.actor_name).to eq(app.name)
            expect(v3event.actee_name).to eq(app_model.name)
            expect(v3event.actee_type).to eq('v3-app')
            expect(v3event.actee).to eq(app_model.guid)
            expect(v3event.metadata['instance']).to eq(payload['instance'])
            expect(v3event.metadata['index']).to eq(payload['index'])
            expect(v3event.metadata['exit_status']).to eq(payload['exit_status'])
            expect(v3event.metadata['exit_description']).to eq(payload['exit_description'])
            expect(v3event.metadata['reason']).to eq(reason)
          end
        end
      end
    end
  end
end
