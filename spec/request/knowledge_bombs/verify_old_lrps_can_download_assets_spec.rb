require 'spec_helper'

##
# While playing #156054638, we discovered that we were unable to remove these
# outdated endpoints. Some legacy LRPs will have these endpoints cached. When
# the LRPs try to restart, such as during a CF upgrade, they will be
# unable to download their assets and will crash unexpectedly.
#
RSpec.describe 'BuildpackBitsController download endpoint exists:' do
  describe 'GET /buildpacks/:path_guid/download' do
    context 'when an lrp tries to download a buildpack without authentication' do
      let(:mister_buildpack) { create(:buildpack) }
      let(:blob_dispatcher) { instance_double(VCAP::CloudController::BlobDispatcher, send_or_redirect: { status: 200 }) }
      let(:staging_user) { 'user' }
      let(:staging_password) { 'password' }
      let(:staging_config) do
        {
          staging: { timeout_in_seconds: 240, auth: { user: staging_user, password: staging_password } }
        }
      end

      before do
        TestConfig.override(**staging_config)
        allow(VCAP::CloudController::BlobDispatcher).to receive(:new).and_return(blob_dispatcher)
      end

      it 'does not return a 404 because the endpoint is still present, or redirect to another endpoint with different auth' do
        get "/v2/buildpacks/#{mister_buildpack.guid}/download"

        expect(last_response.status).not_to eq(404)
        expect(last_response.status).not_to be_between(301, 308)
      end
    end
  end
end

RSpec.describe 'StagingsController download endpoint exists:' do
  describe 'GET /staging/v3/droplets/:guid/download' do
    let(:droplet) { create(:droplet_model) }

    context 'when an lrp tries to download a droplet' do
      it 'does not return a 404 because the endpoint is still present, or redirect to another endpoint with different auth' do
        get "/staging/v3/droplets/#{droplet.guid}/download", nil, {}
        expect(last_response.status).not_to eq(404)
        expect(last_response.status).not_to be_between(301, 308)
      end
    end
  end
end
