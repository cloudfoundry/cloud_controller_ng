require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Apps', type: %i[api legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  let(:space) { VCAP::CloudController::Space.make }
  let(:process) { VCAP::CloudController::ProcessModelFactory.make space: }
  let(:user) { make_developer_for_space(process.space) }
  let(:stager) { instance_double(VCAP::CloudController::Diego::Stager, stage: nil) }

  before do
    allow_any_instance_of(VCAP::CloudController::Stagers).to receive(:validate_process)
    allow_any_instance_of(VCAP::CloudController::Stagers).to receive(:stager_for_build).and_return(stager)
    VCAP::CloudController::Buildpack.make
  end

  authenticated_request

  parameter :guid, 'The guid of the App'
  post '/v2/apps/:guid/restage' do
    example 'Restage an App' do
      client.post "/v2/apps/#{process.guid}/restage", {}, headers
      expect(status).to eq(201), parsed_response.to_s
    end
  end
end
