require 'spec_helper'
require 'rspec_api_documentation/dsl'

resource "Events", :type => :api do
  let(:admin_auth_header) { headers_for(admin_user, :admin_scope => true)["HTTP_AUTHORIZATION"] }
  authenticated_request

  before do
    3.times do
      VCAP::CloudController::Event.make
    end
  end

  let(:guid) { VCAP::CloudController::Event.first.guid }

  standard_parameters

  field :space_guid, "The guid of the associated space.", required: true, readonly: true
  field :space_url, "The url of the associated space.", required: false, readonly: true

  standard_model_object :event # adds get /v2/users/ and get /v2/users/:guid
end
