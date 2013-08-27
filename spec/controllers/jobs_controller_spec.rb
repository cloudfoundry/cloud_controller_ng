module VCAP::CloudController
  describe VCAP::CloudController::JobsController, type: :controller do
    describe "GET /v2/jobs/:id" do
      context "when the job is still running" do
        it "returns" do
          {errors: [], state: "running"}
        end
      end
      context "when the job is finished" do
        it "returns" do
          {errors: [], state: "finished"}
        end
      end
      context "when the job failed" do
        it "returns" do
          {errors: [10001, ""], state: "failed"}
        end
      end
      context "when the job doesn't exist"
      context "when you don't have permissions to the job"
    end
  end
end