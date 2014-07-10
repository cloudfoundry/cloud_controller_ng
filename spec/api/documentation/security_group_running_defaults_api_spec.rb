require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Security Group Running Defaults", :type => :api do
  let(:admin_auth_header) { admin_headers["HTTP_AUTHORIZATION"] }
  let!(:sec_group) { VCAP::CloudController::SecurityGroup.make }
  let!(:running_default_sec_group) { VCAP::CloudController::SecurityGroup.make(running_default: true) }

  authenticated_request

  put "/v2/config/running_security_groups/:guid" do
    example "Set a Security Group as a default for running Apps" do
      client.put "/v2/config/running_security_groups/#{sec_group.guid}", {}, headers
      expect(status).to eq(200)

      standard_entity_response parsed_response, :security_group
    end
  end

  delete "/v2/config/running_security_groups/:guid" do
    example "Removing a Security Group as a default for running Apps" do
      client.delete "/v2/config/running_security_groups/#{running_default_sec_group.guid}", {}, headers
      expect(status).to eq(204)
    end
  end

  get "/v2/config/running_security_groups" do
    example "Return the Security Groups used for running Apps" do
      client.get "/v2/config/running_security_groups", {}, headers
      expect(status).to eq(200)
      standard_list_response parsed_response, :security_group
    end
  end
end
