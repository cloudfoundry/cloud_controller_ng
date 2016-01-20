require 'spec_helper'

module CloudController
  module Blobstore
    describe UrlGenerator do
      let(:blobstore_options) do
        {
          blobstore_host: 'api.example.com',
          blobstore_port: 9292,
          user:           'username',
          password:       'password',
        }
      end

      let(:package_blobstore) { instance_double(Blobstore::Client) }
      let(:buildpack_cache_blobstore) { instance_double(Blobstore::Client) }
      let(:admin_buildpack_blobstore) { instance_double(Blobstore::Client) }
      let(:droplet_blobstore) { instance_double(Blobstore::Client) }
      let(:internal_url_generator) { instance_double(InternalUrlGenerator) }
      let(:local_url_generator) { instance_double(LocalUrlGenerator) }
      let(:upload_url_generator) { instance_double(UploadUrlGenerator) }

      subject(:url_generator) do
        described_class.new(blobstore_options,
          package_blobstore,
          buildpack_cache_blobstore,
          admin_buildpack_blobstore,
          droplet_blobstore)
      end

      before do
        allow(InternalUrlGenerator).to receive(:new).and_return(internal_url_generator)
        allow(LocalUrlGenerator).to receive(:new).and_return(local_url_generator)
        allow(UploadUrlGenerator).to receive(:new).and_return(upload_url_generator)
      end

      context 'downloads' do
        describe 'app package' do
          let(:app) { double(:app) }

          it 'delegates to local_url_generator when local' do
            allow(package_blobstore).to receive(:local?).and_return(true)
            allow(local_url_generator).to receive(:app_package_download_url)
            url_generator.app_package_download_url(app)
            expect(local_url_generator).to have_received(:app_package_download_url).with(app)
          end

          it 'delegates to internal_url_generator when not local' do
            allow(package_blobstore).to receive(:local?).and_return(false)
            allow(internal_url_generator).to receive(:app_package_download_url)
            url_generator.app_package_download_url(app)
            expect(internal_url_generator).to have_received(:app_package_download_url).with(app)
          end
        end

        describe 'buildpack cache' do
          let(:app) { double(:app) }

          it 'delegates to local_url_generator when local' do
            allow(buildpack_cache_blobstore).to receive(:local?).and_return(true)
            allow(local_url_generator).to receive(:buildpack_cache_download_url)
            url_generator.buildpack_cache_download_url(app)
            expect(local_url_generator).to have_received(:buildpack_cache_download_url).with(app)
          end

          it 'delegates to internal_url_generator when not local' do
            allow(buildpack_cache_blobstore).to receive(:local?).and_return(false)
            allow(internal_url_generator).to receive(:buildpack_cache_download_url)
            url_generator.buildpack_cache_download_url(app)
            expect(internal_url_generator).to have_received(:buildpack_cache_download_url).with(app)
          end
        end

        describe 'admin buildpacks' do
          let(:buildpack) { VCAP::CloudController::Buildpack.make }

          it 'delegates to local_url_generator when local' do
            allow(admin_buildpack_blobstore).to receive(:local?).and_return(true)
            allow(local_url_generator).to receive(:admin_buildpack_download_url)
            url_generator.admin_buildpack_download_url(buildpack)
            expect(local_url_generator).to have_received(:admin_buildpack_download_url).with(buildpack)
          end

          it 'delegates to internal_url_generator when not local' do
            allow(admin_buildpack_blobstore).to receive(:local?).and_return(false)
            allow(internal_url_generator).to receive(:admin_buildpack_download_url)
            url_generator.admin_buildpack_download_url(buildpack)
            expect(internal_url_generator).to have_received(:admin_buildpack_download_url).with(buildpack)
          end
        end

        describe 'download droplets' do
          let(:app) { double(:app) }

          it 'delegates to local_url_generator when local' do
            allow(droplet_blobstore).to receive(:local?).and_return(true)
            allow(local_url_generator).to receive(:droplet_download_url)
            url_generator.droplet_download_url(app)
            expect(local_url_generator).to have_received(:droplet_download_url).with(app)
          end

          it 'delegates to internal_url_generator when not local' do
            allow(droplet_blobstore).to receive(:local?).and_return(false)
            allow(internal_url_generator).to receive(:droplet_download_url)
            url_generator.droplet_download_url(app)
            expect(internal_url_generator).to have_received(:droplet_download_url).with(app)
          end
        end

        describe 'download unauthorized droplets permalink' do
          let(:app) { VCAP::CloudController::AppFactory.make }

          it 'gives out a url to the cloud controller' do
            expect(url_generator.unauthorized_perma_droplet_download_url(app)).to eql("http://api.example.com:9292/internal/v2/droplets/#{app.guid}/#{app.droplet_hash}/download")
          end

          context 'when no droplet_hash' do
            before do
              app.droplet_hash = nil
              app.save
            end

            it 'returns nil if no droplet_hash' do
              expect(url_generator.unauthorized_perma_droplet_download_url(app)).to be_nil
            end
          end
        end

        context 'v3 urls' do
          describe 'v3 droplet downloads' do
            let(:droplet) { double(:droplet) }

            it 'delegates to local_url_generator when local' do
              allow(droplet_blobstore).to receive(:local?).and_return(true)
              allow(local_url_generator).to receive(:v3_droplet_download_url)
              url_generator.v3_droplet_download_url(droplet)
              expect(local_url_generator).to have_received(:v3_droplet_download_url).with(droplet)
            end

            it 'delegates to internal_url_generator when not local' do
              allow(droplet_blobstore).to receive(:local?).and_return(false)
              allow(internal_url_generator).to receive(:v3_droplet_download_url)
              url_generator.v3_droplet_download_url(droplet)
              expect(internal_url_generator).to have_received(:v3_droplet_download_url).with(droplet)
            end
          end

          describe 'download app buildpack cache' do
            let(:app_guid) { Sham.guid }
            let(:stack) { Sham.name }

            it 'delegates to local_url_generator when local' do
              allow(buildpack_cache_blobstore).to receive(:local?).and_return(true)
              allow(local_url_generator).to receive(:v3_app_buildpack_cache_download_url)
              url_generator.v3_app_buildpack_cache_download_url(app_guid, stack)
              expect(local_url_generator).to have_received(:v3_app_buildpack_cache_download_url).with(app_guid, stack)
            end

            it 'delegates to internal_url_generator when not local' do
              allow(buildpack_cache_blobstore).to receive(:local?).and_return(false)
              allow(internal_url_generator).to receive(:v3_app_buildpack_cache_download_url)
              url_generator.v3_app_buildpack_cache_download_url(app_guid, stack)
              expect(internal_url_generator).to have_received(:v3_app_buildpack_cache_download_url).with(app_guid, stack)
            end
          end

          describe 'package' do
            let(:package) { double(:package) }

            it 'delegates to local_url_generator when local' do
              allow(package_blobstore).to receive(:local?).and_return(true)
              allow(local_url_generator).to receive(:package_download_url)
              url_generator.package_download_url(package)
              expect(local_url_generator).to have_received(:package_download_url).with(package)
            end

            it 'delegates to internal_url_generator when not local' do
              allow(package_blobstore).to receive(:local?).and_return(false)
              allow(internal_url_generator).to receive(:package_download_url)
              url_generator.package_download_url(package)
              expect(internal_url_generator).to have_received(:package_download_url).with(package)
            end
          end
        end
      end

      context 'uploads' do
        describe 'droplets' do
          let(:app) { double(:app) }

          it 'delegates to internal_url_generator when not local' do
            allow(upload_url_generator).to receive(:droplet_upload_url)
            url_generator.droplet_upload_url(app)
            expect(upload_url_generator).to have_received(:droplet_upload_url).with(app)
          end
        end

        describe 'buildpack cache' do
          let(:app) { double(:app) }

          it 'delegates to internal_url_generator when not local' do
            allow(upload_url_generator).to receive(:buildpack_cache_upload_url)
            url_generator.buildpack_cache_upload_url(app)
            expect(upload_url_generator).to have_received(:buildpack_cache_upload_url).with(app)
          end
        end

        describe 'v3 buildpack cache' do
          let(:app_guid) { Sham.guid }
          let(:stack) { Sham.name }

          it 'delegates to internal_url_generator when not local' do
            allow(upload_url_generator).to receive(:v3_app_buildpack_cache_upload_url)
            url_generator.v3_app_buildpack_cache_upload_url(app_guid, stack)
            expect(upload_url_generator).to have_received(:v3_app_buildpack_cache_upload_url).with(app_guid, stack)
          end
        end

        describe 'v3 droplet' do
          let(:droplet_guid) { Sham.guid }

          it 'delegates to internal_url_generator when not local' do
            allow(upload_url_generator).to receive(:package_droplet_upload_url)
            url_generator.package_droplet_upload_url(droplet_guid)
            expect(upload_url_generator).to have_received(:package_droplet_upload_url).with(droplet_guid)
          end
        end
      end
    end
  end
end
