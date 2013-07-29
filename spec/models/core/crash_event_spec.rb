require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Models::AppEvent, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:app, :instance_guid,
        :instance_index, :exit_status, :timestamp],
    }
  end
end