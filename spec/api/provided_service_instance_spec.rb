require_relative 'spec_helper'

describe VCAP::CloudController::ProvidedServiceInstance do
  describe "POST /v2/provided_service_instances" do
    it "creates a provided service instance" do
      space = VCAP::CloudController::Models::Space.make
      developer = make_developer_for_space(space)
      payload = {
        'name' => 'provided',
        'space_guid' => space.guid,
        'credentials' => {'jz' => 'dj'},
      }.to_json
      expect { post "/v2/provided_service_instances", payload, headers_for(developer) }.to change {
        VCAP::CloudController::Models::ProvidedServiceInstance.count
      }.by 1
    end
  end
end
