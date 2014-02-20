require "spec_helper"
require "jobs/runtime/model_deletion"
require "models/runtime/app"
require "models/runtime/space"

module VCAP::CloudController
  module Jobs::Runtime
    describe ModelDeletion do
      describe "#perform" do
        let(:space) { Space.make }
        let!(:app) { App.make(space: space) }

        subject(:job) { ModelDeletion.new(Space, space.guid) }

        context "deleting a space" do
          it "can delete the space" do
            expect { job.perform }.to change { Space.count }.by(-1)
          end

          it "can delete the space's associated app" do
            expect { job.perform }.to change { App.count }.by(-1)
          end
        end

        context "deleting an app" do
          subject(:job) { ModelDeletion.new(App, app.guid) }

          it "can delete an app" do
            expect {
              job.perform
            }.to change {
              App.count
            }.by(-1)
          end
        end

        context "when nothing matches the given guid" do
          subject(:job) { ModelDeletion.new(Space, "not_a_guid_at_all") }

          it "just returns" do
            expect {
              job.perform
            }.not_to change { Space.count }
          end
        end

        it "knows its job name" do
          expect(job.job_name).to equal(:model_deletion)
        end
      end
    end
  end
end
