require 'spec_helper'

##
# While playing #156054638, we discovered that we were unable to remove these
# outdated endpoints. Some legacy LRPs will have these endpoints cached. When
# the LRPs try to restart, such as during a CF upgrade, they will be
# unable to download their assets and will crash unexpectedly.
#
RSpec.describe 'BuildpackBitsController download endpoint exists' do
  describe 'GET /buildpacks/:path_guid/download' do
    context 'when an lrp tries to download a buildpack without authentication' do
      it 'returns neither a 404 nor a redirect' do
        get "/v2/buildpacks/101/download", nil, {}
        expect(last_response.status).to eq(401)
      end
    end
  end
end

RSpec.describe 'StagingsController download endpoint exists' do
  describe 'GET /staging/v3/droplets/:guid/download' do
    let(:droplet) { VCAP::CloudController::DropletModel.make }
    context 'when an lrp tries to download a droplet' do
      it 'returns neither a 404 nor a redirect' do
        get "/staging/v3/droplets/#{droplet.guid}/download", nil, {}
        expect(last_response.status).to eq(401)
      end
    end
  end
end
