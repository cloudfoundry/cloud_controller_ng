require "spec_helper"
require "models/runtime/app"
require "models/runtime/space"
require "jobs/runtime/model_deletion_job"

module VCAP::CloudController
  describe ModelDeletionJob do
    describe "#perform" do
      let(:space) { Space.make }
      let!(:app) { App.make(space: space) }

      context "deleting a space" do
        let(:job) { ModelDeletionJob.new(Space, space.guid) }

        it "can delete the space" do
          expect { job.perform }.to change { Space.count }.by(-1)
        end

        it "can delete the space's associated app" do
          expect { job.perform }.to change { App.count }.by(-1)
        end
      end

      it "can delete an app" do
        job = ModelDeletionJob.new(App, app.guid)
        expect {
          job.perform
        }.to change {
          App.count
        }.by(-1)
      end

      context "when nothing matches the given guid" do
        it "just returns" do
          expect {
            ModelDeletionJob.new(Space, "not_a_guid_at_all").perform
          }.not_to change { Space.count }
        end
      end
    end
  end
end