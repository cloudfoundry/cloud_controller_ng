require "spec_helper"

module VCAP::CloudController
  describe ServiceUsageEvent, type: :model do
    let(:valid_attributes) do
      {
        state: Repositories::Services::ServiceUsageEventRepository::CREATED_EVENT_STATE,
        org_guid: 'org-guid',
        space_guid: 'space-guid',
        space_name: 'space-name',
        service_instance_guid: 'service-instance-guid',
        service_instance_name: 'service-instance-name',
        service_instance_type: 'service-instance-type',
        service_plan_guid: 'service-plan-guid',
        service_plan_name: 'service-plan-name',
        service_guid: 'service-guid',
        service_label: 'service-label',
      }
    end

    describe "Serialization" do
      it { should export_attributes :state, :org_guid, :space_guid, :space_name, :service_instance_guid, :service_instance_name,
                                    :service_instance_type, :service_plan_guid, :service_plan_name, :service_guid, :service_label }
      it { should import_attributes }
    end

    describe "required attributes" do
      let(:required_attributes) { [:state, :org_guid, :space_guid, :space_name, :service_instance_guid, :service_instance_name, :service_instance_type] }

      it "throws exception when they are blank" do
        required_attributes.each do |required_attribute|
          expect {
            ServiceUsageEvent.create(valid_attributes.except(required_attribute))
          }.to raise_error(Sequel::DatabaseError)
        end
      end
    end

    describe "optional attributes" do
      let(:optional_attributes) { [:service_plan_guid, :service_plan_name, :service_guid, :service_label] }

      it "does not raise exception when they are missing" do
        expect {
          ServiceUsageEvent.create(valid_attributes.except(optional_attributes))
        }.to_not raise_error
      end
    end
  end
end
