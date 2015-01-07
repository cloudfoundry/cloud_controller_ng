require 'spec_helper'

module VCAP::CloudController
  describe AppBitsDownloadController do
    describe 'GET /v2/app/:id/download' do
      let(:tmpdir) { Dir.mktmpdir }
      let(:app_obj) { AppFactory.make }
      let(:app_obj_without_pkg) { AppFactory.make }
      let(:user) { make_user_for_space(app_obj.space) }
      let(:developer) { make_developer_for_space(app_obj.space) }
      let(:developer2) { make_developer_for_space(app_obj_without_pkg.space) }

      before do
        TestConfig.config
        tmpdir = Dir.mktmpdir
        zipname = File.join(tmpdir, 'test.zip')
        TestZip.create(zipname, 10, 1024)
        Jobs::Runtime::AppBitsPacker.new(app_obj.guid, zipname, []).perform
        FileUtils.rm_rf(tmpdir)
      end

      context 'when app is local' do
        let(:workspace) { Dir.mktmpdir }
        let(:blobstore_config) do
          {
            packages: {
              fog_connection: {
                provider: 'Local',
                local_root: Dir.mktmpdir('packages', workspace)
              },
              app_package_directory_key: 'cc-packages',
            },
            resource_pool: {
              resource_directory_key: 'cc-resources',
              fog_connection: {
                provider: 'Local',
                local_root: Dir.mktmpdir('resourse_pool', workspace)
              }
            },
          }
        end

        before do
          Fog.unmock!
          TestConfig.override(blobstore_config)
          guid = app_obj.guid
          tmpdir = Dir.mktmpdir
          zipname = File.join(tmpdir, 'test.zip')
          TestZip.create(zipname, 10, 1024)
          Jobs::Runtime::AppBitsPacker.new(guid, zipname, []).perform
        end

        context 'when using nginx' do
          it 'redirects to correct nginx URL' do
            get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(developer)
            expect(last_response.status).to eq(200)
            app_bit_path = last_response.headers.fetch('X-Accel-Redirect')
            File.exist?(File.join(workspace, app_bit_path))
          end
        end
      end

      context 'dev app download' do
        it 'should return 404 for an app without a package' do
          get "/v2/apps/#{app_obj_without_pkg.guid}/download", {}, headers_for(developer2)
          expect(last_response.status).to eq(404)
        end

        it 'should return 302 for valid packages' do
          get "/v2/apps/#{app_obj.guid}/download", {}, headers_for(developer)
          expect(last_response.status).to eq(302)
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
