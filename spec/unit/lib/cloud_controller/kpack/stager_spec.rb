require 'spec_helper'
require 'cloud_controller/kpack/stager'
require 'kubernetes/api_client'
require 'messages/build_create_message'
require 'fetchers/kpack_buildpack_list_fetcher'

module Kpack
  RSpec.describe Stager do
    subject(:stager) { Stager.new(
      builder_namespace: 'namespace',
      registry_service_account_name: 'gcr-service-account',
      registry_tag_base: 'gcr.io/capi-images'
    )
    }
    let(:package) { VCAP::CloudController::PackageModel.make }
    let(:environment_variables) { { 'BP_JAVA_VERSION' => '8.*', 'BPL_HEAD_ROOM' => 0, 'VCAP_SERVICES' => { postgres: [] } } }
    let(:staging_memory_in_mb) { 1024 }
    let(:staging_disk_in_mb) { 1024 }
    let(:blobstore_url_generator) do
      instance_double(::CloudController::Blobstore::UrlGenerator,
        package_download_url: 'package-download-url',
      )
    end
    let(:client) { instance_double(Kubernetes::ApiClient) }
    let(:default_builder_obj) {
      Kubeclient::Resource.new(
        metadata: {
          name: 'cf-default-builder',
          creationTimestamp: '2020-06-27T03:13:07Z',
        },
        spec: {
          stack: 'cflinuxfs3-stack',
          store: 'cf-buildpack-store',
          serviceAccount: 'gcr-service-account',
          order: [
            { group: [{ id: 'paketo-community/ruby' }] },
            { group: [{ id: 'paketo-buildpacks/java' }] },
          ],
        },
        status: {
          builderMetadata: [
            { id: 'paketo-community/mri', version: '0.0.131' },
            { id: 'paketo-community/bundler', version: '0.0.117' },
            { id: 'paketo-community/bundle-install', version: '0.0.22' },
            { id: 'paketo-community/rackup', version: '0.0.13' },
            { id: 'paketo-buildpacks/maven', version: '1.4.5' },
            { id: 'paketo-buildpacks/java', version: '1.14.0' },
            { id: 'paketo-community/ruby', version: '0.0.11' },
          ],
          stack: {
            id: 'org.cloudfoundry.stacks.cflinuxfs3'
          },
          conditions: [
            {
              lastTransitionTime: '2020-06-27T03:15:46Z',
              status: 'True',
              type: 'Ready',
            }
          ]
        }
      )
    }
    before do
      allow(CloudController::DependencyLocator.instance).to receive(:k8s_api_client).and_return(client)
      allow(CloudController::DependencyLocator.instance).to receive(:blobstore_url_generator).and_return(blobstore_url_generator)
      allow(client).to receive(:get_image).and_return(nil)
      allow(client).to receive(:get_custom_builder).and_return(default_builder_obj)
    end

    it_behaves_like 'a stager'

    describe '#stage' do
      let(:staging_details) do
        details = VCAP::CloudController::Diego::StagingDetails.new
        details.package = package
        details.environment_variables = environment_variables
        details.staging_memory_in_mb = staging_memory_in_mb
        details.staging_disk_in_mb = staging_disk_in_mb
        details.staging_guid = build.guid
        details.lifecycle = lifecycle
        details
      end
      let(:lifecycle) do
        instance_double(VCAP::CloudController::KpackLifecycle, buildpack_infos: [])
      end
      let(:package) do
        VCAP::CloudController::PackageModel.make(app: VCAP::CloudController::AppModel.make(:kpack))
      end
      let!(:build) { VCAP::CloudController::BuildModel.make(:kpack) }
      let!(:droplet) { VCAP::CloudController::DropletModel.make(:docker, app: package.app) }
      before do
        allow_any_instance_of(VCAP::CloudController::DropletCreate).to receive(:create_docker_droplet).with(build).and_return(droplet)
      end
      it 'checks if the image exists' do
        allow(client).to receive(:create_image)
        expect(client).to receive(:get_image).with(package.app.guid, 'namespace').and_return(nil)
        stager.stage(staging_details)
      end

      it 'creates an image using the kpack client' do
        expect(client).to_not receive(:update_image)
        expect(client).to_not receive(:create_custom_builder)
        expect(client).to receive(:create_image).with(Kubeclient::Resource.new({
          metadata: {
            name: package.app.guid,
            namespace: 'namespace',
            labels: {
              Stager::DROPLET_GUID_LABEL_KEY => droplet.guid,
              Stager::APP_GUID_LABEL_KEY => package.app.guid,
              Stager::BUILD_GUID_LABEL_KEY => build.guid,
              Stager::STAGING_SOURCE_LABEL_KEY => 'STG',
            },
            annotations: {
              'sidecar.istio.io/inject' => 'false'
            }
          },
          spec: {
            tag: "gcr.io/capi-images/#{package.app.guid}",
            serviceAccount: 'gcr-service-account',
            builder: {
              name: 'cf-default-builder',
              kind: 'CustomBuilder'
            },
            source: {
              blob: {
                url: 'package-download-url',
              }
            },
            build: {
              env: [
                { name: 'BP_JAVA_VERSION', value: '8.*' },
                { name: 'BPL_HEAD_ROOM', value: '0' },
              ]
            }
          }
        }))

        stager.stage(staging_details)
        expect(blobstore_url_generator).to have_received(:package_download_url).with(package)
      end

      context 'when specifying buildpacks for a build' do
        let(:staging_message) do
          VCAP::CloudController::BuildCreateMessage.new(lifecycle: { data: { buildpacks: ['paketo-buildpacks/java'] }, type: 'kpack' })
        end
        let(:lifecycle) do
          VCAP::CloudController::KpackLifecycle.new(package, staging_message)
        end
        let(:package) { VCAP::CloudController::PackageModel.make(app: VCAP::CloudController::AppModel.make(:kpack)) }

        before do
          allow(client).to receive(:get_custom_builder).
            with("app-#{package.app.guid}", 'namespace').
            and_return(nil)
        end

        it 'creates a custom builder' do
          expect(client).to receive(:create_custom_builder).with(Kubeclient::Resource.new({
            kind: 'CustomBuilder',
            metadata: {
              name: "app-#{package.app.guid}",
              namespace: 'namespace',
              labels: {
                'cloudfoundry.org/app_guid' => package.app.guid,
                'cloudfoundry.org/build_guid' => build.guid,
                'cloudfoundry.org/source_type' => 'STG'
              }
            },
            spec: {
              tag: "gcr.io/capi-images/#{package.app.guid}-custom-builder",
              serviceAccount: 'gcr-service-account',
              stack: 'cflinuxfs3-stack',
              store: 'cf-buildpack-store',
              order: [
                { group: [{ id: 'paketo-buildpacks/java' }] },
              ],
            }
          }))
          expect(client).to receive(:create_image)

          stager.stage(staging_details)
        end

        context 'when the custombuilder already exists' do
          before do
            allow(client).to receive(:get_custom_builder).
              with("app-#{package.app.guid}", 'namespace').
              and_return(Kubeclient::Resource.new({
                kind: 'CustomBuilder',
                apiVersion: 'fake',
                metadata: {
                  resourceVersion: 'bogus',
                },
              }))
          end

          it 'overrides the existing custombuilder' do
            expect(client).to receive(:update_custom_builder).with(Kubeclient::Resource.new({
              kind: 'CustomBuilder',
              apiVersion: 'fake',
              metadata: {
                resourceVersion: 'bogus',
                name: "app-#{package.app.guid}",
                namespace: 'namespace',
                labels: {
                  'cloudfoundry.org/app_guid' => package.app.guid,
                  'cloudfoundry.org/build_guid' => build.guid,
                  'cloudfoundry.org/source_type' => 'STG'
                }
              },
              spec: {
                tag: "gcr.io/capi-images/#{package.app.guid}-custom-builder",
                serviceAccount: 'gcr-service-account',
                stack: 'cflinuxfs3-stack',
                store: 'cf-buildpack-store',
                order: [
                  { group: [{ id: 'paketo-buildpacks/java' }] },
                ],
              }
            }))
            expect(client).to receive(:create_image)

            stager.stage(staging_details)
          end
        end
      end

      context 'when staging fails' do
        before do
          allow(client).to receive(:create_image).and_raise(CloudController::Errors::ApiError.new_from_details('StagerError', 'staging failed'))
        end

        it 'bubbles the error' do
          expect {
            stager.stage(staging_details)
          }.to raise_error(CloudController::Errors::ApiError)

          build.reload
          expect(build.state).to eq(VCAP::CloudController::BuildModel::FAILED_STATE)
          expect(build.error_id).to eq('StagingError')
          expect(build.error_description).to eq("Staging error: Failed to create Image resource for Kpack: 'Stager error: staging failed'")
        end
      end

      context 'when an image already exists' do
        let(:existing_image) do
          Kubeclient::Resource.new({
            apiVersion: 'foo.api.version',
            kind: 'Image',
            metadata: {
              name: package.app.guid,
              namespace: 'namespace',
              creationTimestamp: 'some-timestamp',
              generation: 1,
              labels: {
                Stager::APP_GUID_LABEL_KEY => package.app.guid,
                Stager::BUILD_GUID_LABEL_KEY => 'old-build-guid',
                Stager::STAGING_SOURCE_LABEL_KEY => 'STG',
              },
              annotations: {
                'sidecar.istio.io/inject' => 'false'
              }
            },
            spec: {
              tag: "gcr.io/capi-images/#{package.app.guid}",
              serviceAccount: 'gcr-service-account',
              builder: {
                name: 'cf-autodetect-builder', # legacy Builder to verify that image update includes new CustomBuilder
                kind: 'Builder'
              },
              source: {
                blob: {
                  url: 'old-package-url',
                }
              },
              build: {
                env: [],
              }
            }
          })
        end

        let(:environment_variables) do
          { 'VCAP_SERVICES' => 'ignored', 'FOO' => 'BAR' }
        end

        before do
          allow(client).to receive(:get_image).with(package.app.guid, 'namespace').and_return(existing_image)
        end

        it 'updates the existing Image resource' do
          updated_image = Kubeclient::Resource.new(existing_image.to_hash)
          updated_image.metadata.labels[Kpack::Stager::BUILD_GUID_LABEL_KEY.to_sym] = build.guid
          updated_image.spec.source.blob.url = 'package-download-url'
          updated_image.spec.build.env = [
            { name: 'FOO', value: 'BAR' }
          ]
          updated_image.spec.builder.kind = 'CustomBuilder'
          updated_image.spec.builder.name = 'cf-default-builder'

          expect(client).to_not receive(:create_image)
          expect(client).to receive(:update_image).with(updated_image)

          subject.stage(staging_details)
        end
      end
    end
  end
end
