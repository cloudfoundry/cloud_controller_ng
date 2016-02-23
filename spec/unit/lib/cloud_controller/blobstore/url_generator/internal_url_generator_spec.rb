require 'spec_helper'
require 'cloud_controller/blobstore/url_generator/internal_url_generator'

module CloudController
  module Blobstore
    describe InternalUrlGenerator do
      let(:blobstore_host) do
        'api.example.com'
      end
      let(:blobstore_port) do
        9292
      end
      let(:connection_options) do
        {
          blobstore_host: blobstore_host,
          blobstore_port: blobstore_port,
          user:           username,
          password:       password,
        }
      end

      let(:username) { 'username' }
      let(:password) { 'password' }

      let(:package_blobstore) { instance_double(Blobstore::Client, blob: blob) }
      let(:buildpack_cache_blobstore) { instance_double(Blobstore::Client, blob: blob) }
      let(:admin_buildpack_blobstore) { instance_double(Blobstore::Client, blob: blob) }
      let(:droplet_blobstore) { instance_double(Blobstore::Client, blob: blob) }

      let(:internal_url) { 'http://s3.internal.example.com/signed' }
      let(:blob) { instance_double(Blobstore::FogBlob, internal_download_url: internal_url) }

      subject(:url_generator) do
        described_class.new(connection_options,
          package_blobstore,
          buildpack_cache_blobstore,
          admin_buildpack_blobstore,
          droplet_blobstore)
      end

      let(:app) { VCAP::CloudController::AppFactory.make }

      describe '#app_package_download_url' do
        it 'gives out signed url to remote blobstore for appbits' do
          expect(url_generator.app_package_download_url(app)).to eql(internal_url)
          expect(package_blobstore).to have_received(:blob).with(app.guid)
        end

        context 'when package does not exist' do
          before do
            allow(package_blobstore).to receive(:blob).and_return(nil)
          end

          it 'returns nil' do
            expect(url_generator.app_package_download_url(app)).to be_nil
          end
        end

        context "when the droplet doesn't exist (app created before droplet)" do
          it 'should return a nil url for stage/start first instance' do
            app.droplets_dataset.destroy
            app.droplet_hash = nil
            app.save
            app.reload
            expect(url_generator.droplet_download_url(app)).to be_nil
          end
        end

        context 'when a SigningRequestError is raised' do
          before do
            allow(blob).to receive(:internal_download_url).and_raise(SigningRequestError.new('failed to get signed url'))
          end

          it 'returns nil' do
            expect(url_generator.app_package_download_url(app)).to be_nil
          end
        end
      end

      describe '#buildpack_cache_download_url' do
        it 'gives out signed url to remote blobstore for buildpack cache' do
          expect(url_generator.buildpack_cache_download_url(app)).to eql(internal_url)
          expect(buildpack_cache_blobstore).to have_received(:blob).with(app.buildpack_cache_key)
        end

        context 'when buildpack cache does not exist' do
          before do
            allow(buildpack_cache_blobstore).to receive(:blob).and_return(nil)
          end

          it 'returns nil' do
            expect(url_generator.buildpack_cache_download_url(app)).to be_nil
          end
        end

        context 'when a SigningRequestError is raised' do
          before do
            allow(blob).to receive(:internal_download_url).and_raise(SigningRequestError.new('failed to get signed url'))
          end

          it 'returns nil' do
            expect(url_generator.buildpack_cache_download_url(app)).to be_nil
          end
        end
      end

      describe '#admin_buildpack_download_url' do
        let(:buildpack) { VCAP::CloudController::Buildpack.make }

        it 'gives out signed url to remote blobstore for admin buildpack' do
          expect(url_generator.admin_buildpack_download_url(buildpack)).to eql(internal_url)
          expect(admin_buildpack_blobstore).to have_received(:blob).with(buildpack.key)
        end

        context 'when the buildpack does not exist' do
          before do
            allow(admin_buildpack_blobstore).to receive(:blob).and_return(nil)
          end

          it 'returns nil' do
            expect(url_generator.admin_buildpack_download_url(buildpack)).to be_nil
          end
        end

        context 'when a SigningRequestError is raised' do
          before do
            allow(blob).to receive(:internal_download_url).and_raise(SigningRequestError.new('failed to get signed url'))
          end

          it 'returns nil' do
            expect(url_generator.admin_buildpack_download_url(buildpack)).to be_nil
          end
        end
      end

      describe '#droplet_download_url' do
        before do
          allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).
            and_return(droplet_blobstore)
        end

        it 'gives out signed url to remote blobstore from the blob' do
          expect(url_generator.droplet_download_url(app)).to eql(internal_url)
        end

        context 'when the droplet does not exist' do
          before do
            app.droplet_hash = nil
            app.save
          end

          it 'returns nil' do
            expect(url_generator.droplet_download_url(app)).to be_nil
          end
        end

        context 'when a SigningRequestError is raised' do
          before do
            allow(blob).to receive(:internal_download_url).and_raise(SigningRequestError.new('failed to get signed url'))
          end

          it 'returns nil' do
            expect(url_generator.droplet_download_url(app)).to be_nil
          end
        end
      end

      context 'v3 urls' do
        describe '#v3_droplet_download_url' do
          let(:droplet) { VCAP::CloudController::DropletModel.make }

          it 'gives out signed url to remote blobstore from the blob' do
            expect(url_generator.v3_droplet_download_url(droplet)).to eql(internal_url)
            expect(droplet_blobstore).to have_received(:blob).with(droplet.blobstore_key)
          end

          context 'when the droplet does not exist' do
            before do
              allow(droplet_blobstore).to receive(:blob).and_return(nil)
            end

            it 'returns nil' do
              expect(url_generator.v3_droplet_download_url(droplet)).to be_nil
            end
          end

          context 'when a SigningRequestError is raised' do
            before do
              allow(blob).to receive(:internal_download_url).and_raise(SigningRequestError.new('failed to get signed url'))
            end

            it 'returns nil' do
              expect(url_generator.v3_droplet_download_url(droplet)).to be_nil
            end
          end
        end

        describe '#v3_app_buildpack_cache_download_url' do
          let(:app_model) { double(:app_model, guid: Sham.guid) }
          let(:stack) { Sham.name }

          it 'gives out signed url to remote blobstore for buildpack cache' do
            expect(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack)).to eql(internal_url)
            expect(buildpack_cache_blobstore).to have_received(:blob).with("#{app_model.guid}/#{stack}")
          end

          context 'when the buildpack cache does not exist' do
            before do
              allow(buildpack_cache_blobstore).to receive(:blob).and_return(nil)
            end

            it 'returns nil' do
              expect(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack)).to be_nil
            end
          end

          context 'when a SigningRequestError is raised' do
            before do
              allow(blob).to receive(:internal_download_url).and_raise(SigningRequestError.new('failed to get signed url'))
            end

            it 'returns nil' do
              expect(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack)).to be_nil
            end
          end
        end

        describe '#package_download_url' do
          let(:package) { VCAP::CloudController::PackageModel.make }

          it 'gives out signed url to remote blobstore for package' do
            expect(url_generator.package_download_url(package)).to eql(internal_url)
            expect(package_blobstore).to have_received(:blob).with(package.guid)
          end

          context 'and the package does not exist' do
            before { allow(package_blobstore).to receive_messages(blob: nil) }

            it 'returns nil' do
              expect(url_generator.package_download_url(package)).to be_nil
            end
          end

          context 'when a SigningRequestError is raised' do
            before do
              allow(blob).to receive(:internal_download_url).and_raise(SigningRequestError.new('failed to get signed url'))
            end

            it 'returns nil' do
              expect(url_generator.package_download_url(app)).to be_nil
            end
          end
        end
      end
    end
  end
end
