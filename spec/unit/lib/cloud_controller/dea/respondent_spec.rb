require "spec_helper"
require "cloud_controller/dea/respondent"

module VCAP::CloudController
  describe Dea::Respondent do
    before { allow(message_bus).to receive(:subscribe).with(anything) }

    let(:message_bus) { double("message_bus") }

    let(:app) do
      AppFactory.make(
        :instances => 2, :state => 'STARTED', :package_hash => "SOME_HASH", :package_state => "STAGED"
      ).save
    end

    let(:droplet) { app.guid }
    let(:reason) { "CRASHED" }
    let(:payload) do
      {
        'cc_partition' => "cc_partition",
        'droplet' => droplet,
        'version' => app.version,
        'instance' => "instance_id",
        'index' => 0,
        'reason' => reason,
        'exit_status' => 145,
        'exit_description' => "Exit description",
      }
    end

    subject(:respondent) { Dea::Respondent.new(message_bus) }

    describe "#initialize" do
      it "sets logger to a Steno Logger with tag 'cc.dea_respondent'" do
        logger = respondent.logger
        expect(logger).to be_a_kind_of Steno::Logger
        expect(logger.name).to eq("cc.dea_respondent")
      end
    end

    describe "#start" do
      it "subscribes to 'droplet.exited' with a queue" do
        expect(message_bus).to receive(:subscribe).with("droplet.exited",
          :queue => VCAP::CloudController::Dea::Respondent::CRASH_EVENT_QUEUE)

        respondent.start
      end
    end

    describe "#process_droplet_exited_message" do
      context "when the app crashed" do
        context "the app described in the event exists" do
          it "adds a record in the AppEvents table for legacy purposes" do
            time = Time.now
            Timecop.freeze(time) do
              respondent.process_droplet_exited_message(payload)

              app_event = AppEvent.find(:app_id => app.id)

              expect(app_event).not_to be_nil
              expect(app_event.instance_guid).to eq(payload['instance'])
              expect(app_event.instance_index).to eq(payload['index'])
              expect(app_event.exit_status).to eq(payload['exit_status'])
              expect(app_event.exit_description).to eq(payload['exit_description'])
              expect(app_event.timestamp.to_i).to eq(time.to_i)
            end
          end

          it "adds a record in the Events table" do
            time = Time.now
            Timecop.freeze(time) do
              respondent.process_droplet_exited_message(payload)

              app_event = Event.find(:actee => app.guid)

              expect(app_event).to be
              expect(app_event.space).to eq(app.space)
              expect(app_event.type).to eq("app.crash")
              expect(app_event.timestamp.to_i).to eq(time.to_i)
              expect(app_event.actor_type).to eq("app")
              expect(app_event.actor).to eq(app.guid)
              expect(app_event.metadata["instance"]).to eq(payload['instance'])
              expect(app_event.metadata["index"]).to eq(payload['index'])
              expect(app_event.metadata["exit_status"]).to eq(payload['exit_status'])
              expect(app_event.metadata["exit_description"]).to eq(payload['exit_description'])
              expect(app_event.metadata["reason"]).to eq(reason)
            end
          end
        end

        context "the app described in the event does not exist" do
          let(:droplet) { "non existent droplet" }

          it "does not add a record in the AppEvents table" do
            expect(AppEvent).not_to receive(:create)
            respondent.process_droplet_exited_message(payload)
          end
        end
      end

      context "when the app did not crash" do
        let(:reason) { "STOPPED" }

        context "the app described in the event exists" do
          it "does not add a record in the AppEvents table" do
            expect(AppEvent).not_to receive(:create)
            respondent.process_droplet_exited_message(payload)
          end
        end

        context "the app described in the event does not exist" do
          it "does not add a record in the AppEvents table" do
            expect(AppEvent).not_to receive(:create)
            respondent.process_droplet_exited_message(payload)
          end
        end
      end

      context "when the droplet.exited message contains no reason" do
        let(:reason) { nil }

        it "does not add a record in the AppEvents table" do
          expect(AppEvent).not_to receive(:create)
          respondent.process_droplet_exited_message(payload)
        end
      end
    end
  end
end
