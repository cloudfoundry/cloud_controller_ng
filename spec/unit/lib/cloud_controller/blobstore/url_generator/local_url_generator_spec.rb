require 'spec_helper'
require 'cloud_controller/blobstore/url_generator/local_url_generator'

module CloudController
  module Blobstore
    RSpec.describe LocalUrlGenerator do
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

      let(:package_blobstore) { instance_double(Blobstore::Client, exists?: true) }
      let(:buildpack_cache_blobstore) { instance_double(Blobstore::Client, exists?: true) }
      let(:admin_buildpack_blobstore) { instance_double(Blobstore::Client, exists?: true) }
      let(:droplet_blobstore) { instance_double(Blobstore::Client, exists?: true) }

      subject(:url_generator) do
        LocalUrlGenerator.new(connection_options,
          package_blobstore,
          buildpack_cache_blobstore,
          admin_buildpack_blobstore,
          droplet_blobstore)
      end

      let(:app) { VCAP::CloudController::AppFactory.make }

      describe 'app package' do
        it 'gives a local URI to the blobstore host/port' do
          uri = URI.parse(url_generator.app_package_download_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/apps/#{app.guid}"
        end

        context 'and the package does not exist' do
          before { allow(package_blobstore).to receive_messages(exists?: false) }

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
      end

      describe 'buildpack cache' do
        it 'gives a local URI to the blobstore host/port' do
          uri = URI.parse(url_generator.buildpack_cache_download_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/buildpack_cache/#{app.guid}/download"
        end

        context 'and the package does not exist' do
          before { allow(buildpack_cache_blobstore).to receive_messages(exists?: false) }

          it 'returns nil' do
            expect(url_generator.buildpack_cache_download_url(app)).to be_nil
          end
        end
      end

      describe 'admin buildpacks' do
        let(:buildpack) { VCAP::CloudController::Buildpack.make }

        it 'gives a local URI to the blobstore host/port' do
          uri = URI.parse(url_generator.admin_buildpack_download_url(buildpack))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/v2/buildpacks/#{buildpack.guid}/download"
        end

        context 'and the package does not exist' do
          before { allow(admin_buildpack_blobstore).to receive_messages(exists?: false) }

          it 'returns nil' do
            expect(url_generator.admin_buildpack_download_url(buildpack)).to be_nil
          end
        end
      end

      describe 'download droplets' do
        let(:app) { VCAP::CloudController::AppFactory.make }
        let(:blob) { instance_double(Blobstore::FogBlob) }

        before do
          allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).
            and_return(droplet_blobstore)

          allow(droplet_blobstore).to receive(:blob).and_return(blob)
        end

        it 'gives a local URI to the blobstore host/port' do
          uri = URI.parse(url_generator.droplet_download_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/droplets/#{app.guid}/download"
        end

        context 'and the droplet does not exist' do
          before do
            allow(droplet_blobstore).to receive(:blob).and_return(nil)
          end

          it 'returns nil' do
            expect(url_generator.droplet_download_url(app)).to be_nil
          end
        end
      end

      context 'v3 urls' do
        describe 'download app buildpack cache' do
          let(:app_model) { double(:app_model, guid: Sham.guid) }
          let(:stack) { Sham.name }

          it 'gives a local URI to the blobstore host/port' do
            uri = URI.parse(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack))
            expect(uri.host).to eql blobstore_host
            expect(uri.port).to eql blobstore_port
            expect(uri.user).to eql 'username'
            expect(uri.password).to eql 'password'
            expect(uri.path).to eql "/staging/v3/buildpack_cache/#{stack}/#{app_model.guid}/download"
          end

          context 'and the app does not exist in the blobstore' do
            before { allow(buildpack_cache_blobstore).to receive_messages(exists?: false) }

            it 'returns nil' do
              expect(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack)).to be_nil
            end
          end
        end

        describe 'droplet downloads' do
          let(:droplet) { VCAP::CloudController::DropletModel.make }

          it 'returns a url to cloud controller' do
            uri = URI.parse(url_generator.v3_droplet_download_url(droplet))
            expect(uri.host).to eql blobstore_host
            expect(uri.port).to eql blobstore_port
            expect(uri.user).to eql 'username'
            expect(uri.password).to eql 'password'
            expect(uri.path).to eql "/staging/v3/droplets/#{droplet.guid}/download"
          end

          context 'and the droplet does not exist' do
            before { allow(droplet_blobstore).to receive_messages(exists?: false) }

            it 'returns nil' do
              expect(url_generator.v3_droplet_download_url(droplet)).to be_nil
            end
          end
        end

        describe 'package' do
          let(:package) { VCAP::CloudController::PackageModel.make }

          it 'gives a local URI to the blobstore host/port' do
            uri = URI.parse(url_generator.package_download_url(package))
            expect(uri.host).to eql blobstore_host
            expect(uri.port).to eql blobstore_port
            expect(uri.user).to eql 'username'
            expect(uri.password).to eql 'password'
            expect(uri.path).to eql "/staging/packages/#{package.guid}"
          end

          context 'and the package does not exist' do
            before { allow(package_blobstore).to receive_messages(exists?: false) }

            it 'returns nil' do
              expect(url_generator.package_download_url(package)).to be_nil
            end
          end
        end
      end
    end
  end
end
