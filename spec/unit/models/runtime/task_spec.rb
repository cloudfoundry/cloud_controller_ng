require "spec_helper"

module VCAP::CloudController
  describe Task, type: :model do
    let(:app) { AppFactory.make :name => "my app" }
    let(:message_bus) { Config.message_bus }
    let(:secure_token) { "42" }

    before do
      allow(SecureRandom).to receive(:urlsafe_base64).and_return(secure_token)
    end

    subject { Task.make :app => app }

    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :app }
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :app_guid, :secure_token }
      it { is_expected.to import_attributes :app_guid }
    end

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
        expect(SecureRandom).to receive(:urlsafe_base64).and_return(secure_token)
        expect(subject.secure_token).to eq(secure_token)
      end

      it "returns the same token every time" do
        allow(SecureRandom).to receive(:urlsafe_base64).and_call_original

        secure_token = subject.secure_token
        expect(subject.reload.secure_token).to eq(secure_token)
      end
    end

    describe "secure token encryption" do
      let!(:task) { Task.make(:app => app) }

      let(:last_row) { VCAP::CloudController::Task.dataset.naked.order_by(:id).last }

      it "is encrypted" do
        expect(last_row[:secure_token]).not_to eq(secure_token)
      end

      it "is decrypted" do
        task.reload
        expect(task.secure_token).to eq secure_token
      end

      it "salt is unique for each task" do
        other_task = Task.make(:app => app)
        expect(task.salt).not_to eq other_task.salt
      end

      it "must have a salt of length 8" do
        expect(task.salt.length).to eq 8
      end

      it "works with long secure tokens" do
        maddeningly_long_secure_token = "supercalifredgilisticexpialidocious"*1000
        allow(SecureRandom).to receive(:urlsafe_base64).and_return(maddeningly_long_secure_token)

        long_secure_token_task = Task.make(:app => app)
        long_secure_token_task.reload
        expect(long_secure_token_task.secure_token).to eq(maddeningly_long_secure_token)
      end
    end

    describe "#update_from_json" do
      describe "updating app_guid" do
        context "with a valid app" do
          let(:other_app) { AppFactory.make }

          it "updates the relationship" do
            expect {
              subject.update_from_json(%Q|{"app_guid":"#{other_app.guid}"}|)
            }.to change {
              subject.app
            }.from(app).to(other_app)
          end
        end
      end
    end

    describe "#after_commit" do
      it "sends task.start with the URI for the app's droplet", isolation: :truncation do
        expect(CloudController::DependencyLocator.instance.task_client).to receive(:start_task).with(instance_of(Task))
        @task = Task.make :app => app
        allow(@task).to receive_messages(:secure_token => "42")
      end
    end

    describe "#after_destroy_commit", isolation: :truncation do
      it "sends task.stop with the public key, the URI for the app's droplet" do
        task = Task.make :app => app

        expect(CloudController::DependencyLocator.instance.task_client).to receive(:stop_task).with(task)

        task.destroy(savepoint: true)
      end
    end
  end
end
