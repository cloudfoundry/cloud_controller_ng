require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::AppEventsController do
    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:timestamp) }
      it { expect(described_class).to be_queryable_by(:app_guid) }
    end
  end
end
