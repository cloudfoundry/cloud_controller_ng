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

    describe "serialization" do
      it "has the relevant fields" do
        event = AppUsageEvent.make
        json_hash = Yajl::Parser.parse(event.to_json)
        expect(json_hash.fetch('state')).to eq(event.state)
        expect(json_hash.fetch('memory_in_mb_per_instance')).to eq(event.memory_in_mb_per_instance)
        expect(json_hash.fetch('instance_count')).to eq(event.instance_count)
        expect(json_hash.fetch('app_guid')).to eq(event.app_guid)
        expect(json_hash.fetch('app_name')).to eq(event.app_name)
        expect(json_hash.fetch('space_guid')).to eq(event.space_guid)
        expect(json_hash.fetch('space_name')).to eq(event.space_name)
        expect(json_hash.fetch('org_guid')).to eq(event.org_guid)
        expect(json_hash.fetch('buildpack_guid')).to eq(event.buildpack_guid)
        expect(json_hash.fetch('buildpack_name')).to eq(event.buildpack_name)
      end
    end
  end
end
