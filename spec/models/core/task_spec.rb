require "spec_helper"

module VCAP::CloudController
  describe Models::Task, type: :model do
    let(:app) { Models::App.make :name => "my app" }
    let(:message_bus) { CfMessageBus::MockMessageBus.new }
    let(:secure_token) { '42' }

    before do
      CloudController::TaskClient.configure(message_bus)
      SecureRandom.stub(:urlsafe_base64).and_return(secure_token)
    end

    subject { Models::Task.make :app => app }

    it "belongs to an application" do
      expect(subject.app.name).to eq("my app")
    end

    describe "#space" do
      it "returns the app's space, for use by permissions checks" do
        expect(subject.space).to eq(app.space)
      end
    end

    describe "#secure_token" do
      it "uses secure random to generate a random string" do
        SecureRandom.should_receive(:urlsafe_base64).and_return(secure_token)
        expect(subject.secure_token).to eq(secure_token)
      end
    end

    describe "#to_json" do
      it "serializes with app_guid entry" do
        expect(subject.to_json).to json_match hash_including("app_guid" => app.guid)
      end

      it "serializes with secure_token entry" do
        expect(subject.to_json).to json_match hash_including("secure_token" => secure_token)
      end
    end

    describe "#update_from_json" do
      describe "updating app_guid" do
        context "with a valid app" do
          let(:other_app) { Models::App.make }

          it "updates the relationship" do
            expect {
              subject.update_from_json(%Q|{"app_guid":"#{other_app.guid}"}|)
            }.to change {
              subject.app
            }.from(app).to(other_app)
          end
        end

        context "with an invalid app" do
          it "blows up" do
            pending "doesn't currently blow up :("

            expect {
              subject.update_from_json(%Q|{"app_guid":"bad_app_guid"}|)
            }.to raise_error
          end
        end
      end
    end

    describe "#after_commit" do
      it "sends task.start with the URI for the app's droplet" do
        StagingsController.stub(:droplet_download_uri).with(app) do
          "https://some-download-uri"
        end

        task = Models::Task.make :app => app

        task.stub(:secure_token => "42")

        message_bus.should have_published_with_message(
          "task.start",
          :task => task.guid,
          :secure_token => task.secure_token,
          :package => "https://some-download-uri")
      end
    end

    describe "#after_destroy_commit" do
      it "sends task.start with the public key, the URI for the app's droplet" do
        StagingsController.stub(:droplet_download_uri).with(app) do
          "https://some-download-uri"
        end

        task = Models::Task.make :app => app

        task.destroy

        message_bus.should have_published_with_message(
          "task.stop",
          :task => task.guid)
      end
    end
  end
end
