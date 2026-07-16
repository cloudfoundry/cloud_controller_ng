require 'spec_helper'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe AppBitsDownloadController do
    describe 'GET /v2/app/:id/download' do
      let(:process) { ProcessModelFactory.make }
      let(:user) { make_user_for_space(process.space) }
      let(:developer) { make_developer_for_space(process.space) }

      context 'dev app download' do
        before do
          set_current_user(developer)
        end

        it 'returns 404 for an app without a package' do
          get "/v2/apps/#{process.app.guid}/download"
          expect(last_response.status).to eq(404)
        end

        context 'when the package is valid' do
          let(:blob) { instance_double(CloudController::Blobstore::Blob) }

          before do
            allow(blob).to receive(:public_download_url).and_return('http://example.com/somewhere/else')
            allow_any_instance_of(CloudController::Blobstore::Client).to receive(:blob).and_return(blob)
            allow_any_instance_of(CloudController::Blobstore::LocalClient).to receive(:local?).and_return(false)
          end

          it 'returns 302' do
            get "/v2/apps/#{process.app.guid}/download"
            expect(last_response.status).to eq(302)
          end
        end

        it 'returns 404 for non-existent apps' do
          get '/v2/apps/abcd/download'
          expect(last_response.status).to eq(404)
        end
      end

      context 'user app download' do
        before do
          set_current_user(user)
        end

        it 'returns 403' do
          get "/v2/apps/#{process.app.guid}/download"
          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
