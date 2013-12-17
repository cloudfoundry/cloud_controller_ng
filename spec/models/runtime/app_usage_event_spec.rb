require "spec_helper"

module VCAP::CloudController
  describe AppUsageEvent, type: :model do
    let(:valid_attributes) do
      {
        state: 'STARTED',
        memory_in_mb_per_instance: 1,
        instance_count: 1,
        app_guid: 'app-guid',
        app_name: 'app-name',
        space_guid: 'space-guid',
        space_name: 'space-name',
        org_guid: 'org-guid'
      }
    end

    describe "required attributes" do
      let(:required_attributes) { [:state, :memory_in_mb_per_instance, :instance_count, :app_guid, :app_name, :space_guid, :space_name, :org_guid] }

      it "throws exception when they are blank" do
        required_attributes.each do |required_attribute|
          expect {
            AppUsageEvent.create(valid_attributes.except(required_attribute))
          }.to raise_error(Sequel::NotNullConstraintViolation)
        end
      end
    end
  end
end
