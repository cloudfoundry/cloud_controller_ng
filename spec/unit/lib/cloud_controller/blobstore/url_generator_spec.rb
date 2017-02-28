require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe UrlGenerator do
      let(:blobstore_options) do
        {
          blobstore_host: 'api.example.com',
          blobstore_external_port: 9292,
          blobstore_tls_port: 9293,
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

        describe 'droplet' do
          let(:droplet) { double(:droplet) }

          it 'delegates to local_url_generator when local' do
            allow(droplet_blobstore).to receive(:local?).and_return(true)
            allow(local_url_generator).to receive(:droplet_download_url)
            url_generator.droplet_download_url(droplet)
            expect(local_url_generator).to have_received(:droplet_download_url).with(droplet)
          end

          it 'delegates to internal_url_generator when not local' do
            allow(droplet_blobstore).to receive(:local?).and_return(false)
            allow(internal_url_generator).to receive(:droplet_download_url)
            url_generator.droplet_download_url(droplet)
            expect(internal_url_generator).to have_received(:droplet_download_url).with(droplet)
          end
        end

        describe 'buildpack cache' do
          let(:app_guid) { Sham.guid }
          let(:stack) { Sham.name }

          it 'delegates to local_url_generator when local' do
            allow(buildpack_cache_blobstore).to receive(:local?).and_return(true)
            allow(local_url_generator).to receive(:buildpack_cache_download_url)
            url_generator.buildpack_cache_download_url(app_guid, stack)
            expect(local_url_generator).to have_received(:buildpack_cache_download_url).with(app_guid, stack)
          end

          it 'delegates to internal_url_generator when not local' do
            allow(buildpack_cache_blobstore).to receive(:local?).and_return(false)
            allow(internal_url_generator).to receive(:buildpack_cache_download_url)
            url_generator.buildpack_cache_download_url(app_guid, stack)
            expect(internal_url_generator).to have_received(:buildpack_cache_download_url).with(app_guid, stack)
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

      context 'uploads' do
        describe 'droplets' do
          it 'delegates to internal_url_generator when not local' do
            allow(upload_url_generator).to receive(:droplet_upload_url)
            url_generator.droplet_upload_url('droplet-guid')
            expect(upload_url_generator).to have_received(:droplet_upload_url).with('droplet-guid')
          end
        end

        describe 'buildpack cache' do
          it 'delegates to internal_url_generator when not local' do
            allow(upload_url_generator).to receive(:buildpack_cache_upload_url)
            url_generator.buildpack_cache_upload_url('app-guid', 'stack')
            expect(upload_url_generator).to have_received(:buildpack_cache_upload_url).with('app-guid', 'stack')
          end
        end
      end
    end
  end
end
