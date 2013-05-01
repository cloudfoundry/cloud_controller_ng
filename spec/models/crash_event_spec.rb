require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::AppEvent do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:app, :instance_guid,
        :instance_index, :exit_status, :timestamp],
    }
  end
end