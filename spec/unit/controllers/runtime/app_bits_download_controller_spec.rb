require 'spec_helper'

module VCAP::CloudController
  describe AppBitsDownloadController do
    describe 'GET /v2/app/:id/download' do
      let(:app_obj) { AppFactory.make }
      let(:user) { make_user_for_space(app_obj.space) }
      let(:developer) { make_developer_for_space(app_obj.space) }

      context 'dev app download' do
        it 'should return 404 for an app without a package' do
          get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(developer)
          expect(last_response.status).to eq(404)
        end

        context 'when the package is valid' do
          let(:blob) { instance_double(CloudController::Blobstore::FogBlob) }

          before do
            allow(blob).to receive(:public_download_url).and_return('http://example.com/somewhere/else')
            allow_any_instance_of(CloudController::Blobstore::Client).to receive(:blob).and_return(blob)
          end

          it 'should return 302' do
            get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(developer)
            expect(last_response.status).to eq(302)
          end
        end

        it 'should return 404 for non-existent apps' do
          get '/v2/apps/abcd/download', {}, headers_for(developer)
          expect(last_response.status).to eq(404)
        end
      end

      context 'user app download' do
        it 'should return 403' do
          get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(user)
          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
