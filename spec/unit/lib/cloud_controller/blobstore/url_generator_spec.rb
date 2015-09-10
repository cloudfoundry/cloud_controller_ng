require 'spec_helper'

module CloudController
  module Blobstore
    describe UrlGenerator do
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
          user: username,
          password: password,
        }
      end

      let(:username) { 'username' }
      let(:password) { 'password' }

      let(:package_blobstore) { double(local?: true) }
      let(:buildpack_cache_blobstore) { double(local?: true) }
      let(:admin_buildpack_blobstore) { double(local?: true) }
      let(:droplet_blobstore) { double(local?: true) }

      subject(:url_generator) do
        UrlGenerator.new(connection_options,
                         package_blobstore,
                         buildpack_cache_blobstore,
                         admin_buildpack_blobstore,
                         droplet_blobstore)
      end

      let(:app) { VCAP::CloudController::AppFactory.make }

      context 'downloads' do
        describe 'app package' do
          context 'when the packages are stored on local blobstore' do
            context 'and the package exists' do
              before { allow(package_blobstore).to receive_messages(download_uri: '/a/b/c') }

              it 'gives a local URI to the blobstore host/port' do
                uri = URI.parse(url_generator.app_package_download_url(app))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql 'username'
                expect(uri.password).to eql 'password'
                expect(uri.path).to eql "/staging/apps/#{app.guid}"
              end
            end

            context 'and the package does not exist' do
              before { allow(package_blobstore).to receive_messages(download_uri: nil) }

              it 'returns nil' do
                expect(url_generator.app_package_download_url(app)).to be_nil
              end
            end
          end

          context 'when the packages are stored remotely' do
            let(:package_blobstore) { double(local?: false) }

            it 'gives out signed url to remote blobstore for appbits' do
              remote_uri = 'http://s3.example.com/signed'

              expect(package_blobstore).to receive(:download_uri).with(app.guid).and_return(remote_uri)

              expect(url_generator.app_package_download_url(app)).to eql(remote_uri)
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
          context 'when the caches are stored on local blobstore' do
            context 'and the package exists' do
              before { allow(buildpack_cache_blobstore).to receive_messages(download_uri: '/a/b/c') }

              it 'gives a local URI to the blobstore host/port' do
                uri = URI.parse(url_generator.buildpack_cache_download_url(app))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql 'username'
                expect(uri.password).to eql 'password'
                expect(uri.path).to eql "/staging/buildpack_cache/#{app.guid}/download"
              end
            end

            context 'and the package does not exist' do
              before { allow(buildpack_cache_blobstore).to receive_messages(download_uri: nil) }

              it 'returns nil' do
                expect(url_generator.buildpack_cache_download_url(app)).to be_nil
              end
            end
          end

          context 'when the packages are stored remotely' do
            let(:buildpack_cache_blobstore) { double(local?: false) }

            it 'gives out signed url to remote blobstore for appbits' do
              remote_uri = 'http://s3.example.com/signed'

              expect(buildpack_cache_blobstore).to receive(:download_uri).with("#{app.guid}-#{app.stack.name}").and_return(remote_uri)

              expect(url_generator.buildpack_cache_download_url(app)).to eql(remote_uri)
            end
          end
        end

        context 'admin buildpacks' do
          let(:buildpack) { VCAP::CloudController::Buildpack.make }

          context 'when the admin buildpacks are stored on local blobstore' do
            context 'and the package exists' do
              before { allow(admin_buildpack_blobstore).to receive_messages(download_uri: '/a/b/c') }

              it 'gives a local URI to the blobstore host/port' do
                uri = URI.parse(url_generator.admin_buildpack_download_url(buildpack))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql 'username'
                expect(uri.password).to eql 'password'
                expect(uri.path).to eql "/v2/buildpacks/#{buildpack.guid}/download"
              end
            end

            context 'and the package does not exist' do
              before { allow(admin_buildpack_blobstore).to receive_messages(download_uri: nil) }

              it 'returns nil' do
                expect(url_generator.admin_buildpack_download_url(buildpack)).to be_nil
              end
            end
          end

          context 'when the buildpack are stored remotely' do
            let(:admin_buildpack_blobstore) { double(local?: false) }

            it 'gives out signed url to remote blobstore for appbits' do
              remote_uri = 'http://s3.example.com/signed'
              expect(admin_buildpack_blobstore).to receive(:download_uri).with(buildpack.key).and_return(remote_uri)
              expect(url_generator.admin_buildpack_download_url(buildpack)).to eql(remote_uri)
            end
          end
        end

        context 'v3 droplet downloads' do
          let(:droplet) { VCAP::CloudController::DropletModel.make }

          context 'when the blobstore is local' do
            let(:droplet_blobstore) { double(local?: true) }

            it 'returns a url to cloud controller' do
              expect(droplet_blobstore).to receive(:download_uri).with(droplet.blobstore_key).and_return('foobar')
              uri = URI.parse(url_generator.v3_droplet_download_url(droplet))
              expect(uri.host).to eql blobstore_host
              expect(uri.port).to eql blobstore_port
              expect(uri.user).to eql 'username'
              expect(uri.password).to eql 'password'
              expect(uri.path).to eql "/staging/v3/droplets/#{droplet.guid}/download"
            end
          end

          context 'when the blobstore is remote' do
            let(:droplet_blobstore) { double(local?: false) }

            it 'gives out signed url to remote blobstore from the blob' do
              remote_uri = 'http://s3.example.com/signed'
              expect(droplet_blobstore).to receive(:download_uri).with(droplet.blobstore_key).and_return(remote_uri)
              expect(url_generator.v3_droplet_download_url(droplet)).to eql(remote_uri)
            end
          end
        end

        context 'download droplets' do
          let(:app) { VCAP::CloudController::AppFactory.make }
          let(:blob) { double('blob', download_url: 'http://example.com/blob') }

          before do
            allow(CloudController::DependencyLocator.instance).to receive(:droplet_blobstore).
              and_return(droplet_blobstore)
          end

          context 'when the droplets are stored on local blobstore' do
            context 'and the package exists' do
              let(:droplet_blobstore) do
                double(local?: true, blob: blob, exists?: true)
              end

              it 'gives a local URI to the blobstore host/port' do
                uri = URI.parse(url_generator.droplet_download_url(app))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql 'username'
                expect(uri.password).to eql 'password'
                expect(uri.path).to eql "/staging/droplets/#{app.guid}/download"
              end
            end

            context 'and the droplet does not exist' do
              let(:droplet_blobstore) do
                double(local?: true, blob: nil, exists?: false)
              end

              it 'returns nil' do
                expect(url_generator.droplet_download_url(app)).to be_nil
              end
            end
          end

          context 'when the buildpack are stored remotely' do
            let(:droplet_blobstore) do
              double(local?: false, blob: blob, exists?: true)
            end

            it 'gives out signed url to remote blobstore from the blob' do
              expect(url_generator.droplet_download_url(app)).to eql('http://example.com/blob')
            end
          end
        end

        context 'download droplets permalink' do
          it 'gives out a url to the cloud controller' do
            expect(url_generator.perma_droplet_download_url('guid-1')).to eql('http://username:password@api.example.com:9292/staging/droplets/guid-1/download')
          end
        end

        context 'download unauthorized droplets permalink' do
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

        context 'download app buildpack cache' do
          let(:app_model) { double(:app_model, guid: Sham.guid) }
          let(:stack) { Sham.name }

          context 'when the caches are stored on local blobstore' do
            context 'and the app exists' do
              before { allow(buildpack_cache_blobstore).to receive_messages(download_uri: '/a/b/c') }

              it 'gives a local URI to the blobstore host/port' do
                uri = URI.parse(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack))
                expect(uri.host).to eql blobstore_host
                expect(uri.port).to eql blobstore_port
                expect(uri.user).to eql 'username'
                expect(uri.password).to eql 'password'
                expect(uri.path).to eql "/staging/v3/buildpack_cache/#{stack}/#{app_model.guid}/download"
              end
            end

            context 'and the app does not exist in the blobstore' do
              before { allow(buildpack_cache_blobstore).to receive_messages(download_uri: nil) }

              it 'returns nil' do
                expect(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack)).to be_nil
              end
            end
          end

          context 'when the apps are stored remotely' do
            let(:buildpack_cache_blobstore) { double(local?: false) }

            it 'gives out signed url to remote blobstore for appbits' do
              remote_uri = 'http://s3.example.com/signed'

              expect(buildpack_cache_blobstore).to receive(:download_uri).with("#{app_model.guid}-#{stack}").and_return(remote_uri)

              expect(url_generator.v3_app_buildpack_cache_download_url(app_model.guid, stack)).to eql(remote_uri)
            end
          end
        end
      end

      context 'uploads' do
        it 'gives out url for droplets' do
          uri = URI.parse(url_generator.droplet_upload_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/droplets/#{app.guid}/upload"
        end

        it 'gives out url for buidpack cache' do
          uri = URI.parse(url_generator.buildpack_cache_upload_url(app))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/buildpack_cache/#{app.guid}/upload"
        end

        it 'gives out url for app buildpack cache' do
          app_guid = Sham.guid
          stack = Sham.name
          uri = URI.parse(url_generator.v3_app_buildpack_cache_upload_url(app_guid, stack))
          expect(uri.host).to eql blobstore_host
          expect(uri.port).to eql blobstore_port
          expect(uri.user).to eql 'username'
          expect(uri.password).to eql 'password'
          expect(uri.path).to eql "/staging/v3/buildpack_cache/#{stack}/#{app_guid}/upload"
        end
      end
    end
  end
end
