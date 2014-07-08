require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::StacksController do
    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:name) }
    end
  end
end
