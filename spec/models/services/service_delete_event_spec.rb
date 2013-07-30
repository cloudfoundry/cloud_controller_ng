require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Models::ServiceDeleteEvent, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes => [
        :timestamp,
        :organization_guid,
        :organization_name,
        :space_guid,
        :space_name,
        :service_instance_guid,
        :service_instance_name,
      ],
      :db_required_attributes => [
        :timestamp,
        :organization_guid,
        :organization_name,
      ],
      :disable_examples => :deserialization
    }

    describe "create_from_service_instance" do
      context "on an org without billing enabled" do
        it "should do nothing" do
          Models::ServiceDeleteEvent.should_not_receive(:create)
          si = Models::ManagedServiceInstance.make
          org = si.space.organization
          org.billing_enabled = false
          org.save(:validate => false)
          Models::ServiceDeleteEvent.create_from_service_instance(si)
        end
      end

      context "on an org with billing enabled" do
        it "should create an service delete event" do
          Models::ServiceDeleteEvent.should_receive(:create)
          si = Models::ManagedServiceInstance.make
          org = si.space.organization
          org.billing_enabled = true
          org.save(:validate => false)
          Models::ServiceDeleteEvent.create_from_service_instance(si)
        end
      end
    end
  end
end
