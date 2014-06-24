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
        org_guid: 'org-guid',
        buildpack_guid: 'buildpack',
        buildpack_name: 'https://example.com/buildpack.git'
      }
    end

    describe "required attributes" do
      let(:required_attributes) { [:state, :memory_in_mb_per_instance, :instance_count, :app_guid, :app_name, :space_guid, :space_name, :org_guid] }

      it "throws exception when they are blank" do
        required_attributes.each do |required_attribute|
          expect {
            AppUsageEvent.create(valid_attributes.except(required_attribute))
          }.to raise_error(Sequel::DatabaseError)
        end
      end
    end

    describe "optional attributes" do
      let(:optional_attributes) { [:buildpack_guid, :buildpack_name] }

      it "does not raise exception when they are missing" do
        expect {
          AppUsageEvent.create(valid_attributes.except(optional_attributes))
        }.to_not raise_error
      end
    end

    describe "Serialization" do
      it { should export_attributes :state, :memory_in_mb_per_instance, :instance_count, :app_guid, :app_name,
                                    :space_guid, :space_name, :org_guid, :buildpack_guid, :buildpack_name }
      it { should import_attributes }
    end
  end
end
