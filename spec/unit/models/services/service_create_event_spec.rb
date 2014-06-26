require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ServiceCreateEvent, type: :model do
    before do
      TestConfig.override({ :billing_event_writing_enabled => true })
    end

    it { is_expected.to have_timestamp_columns }

    describe "Validations" do
      it { is_expected.to validate_presence :timestamp }
      it { is_expected.to validate_presence :organization_guid }
      it { is_expected.to validate_presence :organization_name }
      it { is_expected.to validate_presence :space_guid }
      it { is_expected.to validate_presence :space_name }
      it { is_expected.to validate_presence :service_instance_guid }
      it { is_expected.to validate_presence :service_instance_name }
      it { is_expected.to validate_presence :service_guid }
      it { is_expected.to validate_presence :service_label }
      it { is_expected.to validate_presence :service_plan_guid }
      it { is_expected.to validate_presence :service_plan_name }
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :timestamp, :event_type, :organization_guid, :organization_name, :space_guid,
                                    :space_name, :service_instance_guid, :service_instance_name, :service_guid,
                                    :service_label, :service_provider, :service_version, :service_plan_guid, :service_plan_name }
      it { is_expected.to import_attributes }
    end

    describe "create_from_service_instance" do
      context "on an org without billing enabled" do
        it "should do nothing" do
          expect(ServiceCreateEvent).not_to receive(:create)
          si = ManagedServiceInstance.make
          org = si.space.organization
          org.billing_enabled = false
          org.save(:validate => false)
          ServiceCreateEvent.create_from_service_instance(si)
        end
      end

      context "on an org with billing enabled" do
        it "should create an service create event" do
          si = ManagedServiceInstance.make
          org = si.space.organization
          org.billing_enabled = true
          org.save(:validate => false)
          expect(ServiceCreateEvent).to receive(:create)
          ServiceCreateEvent.create_from_service_instance(si)
        end
      end
    end
  end
end
