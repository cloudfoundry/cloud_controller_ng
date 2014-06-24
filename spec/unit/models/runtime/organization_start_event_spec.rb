require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::OrganizationStartEvent, type: :model do
    before do
      TestConfig.override({ :billing_event_writing_enabled => true })
    end

    it_behaves_like "a CloudController model", {}

    describe "Validations" do
      it { should validate_presence :timestamp }
      it { should validate_presence :organization_guid }
      it { should validate_presence :organization_name }
    end

    describe "Serialization" do
      it { should export_attributes :timestamp, :event_type, :organization_guid, :organization_name }
      it { should import_attributes }
    end

    describe "create_from_org" do
      context "on an org without billing enabled" do
        it "should raise an error" do
          OrganizationStartEvent.should_not_receive(:create)
          org = Organization.make
          org.billing_enabled = false
          org.save(:validate => false)
          expect {
            OrganizationStartEvent.create_from_org(org)
          }.to raise_error(OrganizationStartEvent::BillingNotEnabled)
        end
      end

      # we don't/can't explicitly test the create path, because that
      # happens automatically when updating the billing_enabled flag
      # on the org. See the org model specs.
    end
  end
end
