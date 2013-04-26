require File.expand_path("../spec_helper", __FILE__)
require "cloud_controller/dea/dea_respondent"

module VCAP::CloudController
  describe DeaRespondent do
    before { message_bus.stub(:subscribe).with(anything) }

    let(:message_bus) { mock("message_bus") }
    let(:configuration) do
      {}
    end

    let(:app) do
      Models::App.make(
        :instances => 2, :state => 'STARTED', :package_hash => "SOME_HASH", :package_state => "STAGED"
      ).save
    end

    let(:droplet) { app.guid }
    let(:reason) { "CRASHED" }
    let(:payload) do
      {
        :cc_partition => "cc_partition",
        :droplet => droplet,
        :version => app.version,
        :instance => "instance_id",
        :index => 0,
        :reason => reason,
        :exit_status => 145,
        :exit_description => "Exit description",
      }
    end

    subject(:respondent) { DeaRespondent.new(configuration, message_bus) }

    describe "#initialize" do
      it "sets logger to a Steno Logger with tag 'cc.dea_respondent'" do
        logger = respondent.logger
        expect(logger).to be_a_kind_of Steno::Logger
        expect(logger.name).to eq("cc.dea_respondent")
      end

      it "subscribes to 'droplet.exited'" do
        message_bus.should_receive(:subscribe).with("droplet.exited")
        respondent
      end
    end

    describe "#process_droplet_exited_message" do
      context "when the app crashed" do
        context "the app described in the event exists" do
          it "adds a record in the CrashEvents table" do
            respondent.process_droplet_exited_message(payload)

            crash_event = Models::CrashEvent.find(:app_id => app.id)

            expect(crash_event).not_to be_nil
            expect(crash_event.instance_guid).to eq(payload[:instance])
            expect(crash_event.instance_index).to eq(payload[:index])
            expect(crash_event.exit_status).to eq(payload[:exit_status])
            expect(crash_event.exit_description).to eq(payload[:exit_description])
          end
        end

        context "the app described in the event does not exist" do
          let(:droplet) { "non existent droplet" }

          it "does not add a record in the CrashEvents table" do
            Models::CrashEvent.should_not_receive(:create)
            respondent.process_droplet_exited_message(payload)
          end
        end
      end

      context "when the app did not crash" do
        let(:reason) { "STOPPED" }

        context "the app described in the event exists" do
          it "does not add a record in the CrashEvents table" do
            Models::CrashEvent.should_not_receive(:create)
            respondent.process_droplet_exited_message(payload)
          end
        end

        context "the app described in the event does not exist" do
          it "does not add a record in the CrashEvents table" do
            Models::CrashEvent.should_not_receive(:create)
            respondent.process_droplet_exited_message(payload)
          end
        end
      end

      context "when the droplet.exited message contains no reason" do
        let(:reason) { nil }

        it "does not add a record in the CrashEvents table" do
          Models::CrashEvent.should_not_receive(:create)
          respondent.process_droplet_exited_message(payload)
        end
      end
    end
  end
end