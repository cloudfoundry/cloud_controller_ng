require 'spec_helper'
require 'presenters/v3/package_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe PackagePresenter do
    describe '#to_hash' do
      let(:show_bits_service_upload_link) { true }
      let(:result) { PackagePresenter.new(package, show_bits_service_upload_link: show_bits_service_upload_link).to_hash }
      let(:package) { VCAP::CloudController::PackageModel.make(type: 'package_type', sha256_checksum: 'sha256') }

      let!(:release_label) do
        VCAP::CloudController::PackageLabelModel.make(
          key_name: 'release',
          value: 'stable',
          resource_guid: package.guid
        )
      end

      let!(:potato_label) do
        VCAP::CloudController::PackageLabelModel.make(
          key_prefix: 'canberra.au',
          key_name: 'potato',
          value: 'mashed',
          resource_guid: package.guid
        )
      end

      let!(:mountain_annotation) do
        VCAP::CloudController::PackageAnnotationModel.make(
          key: 'altitude',
          value: '14,412',
          resource_guid: package.guid,
        )
      end

      let!(:plain_annotation) do
        VCAP::CloudController::PackageAnnotationModel.make(
          key: 'maize',
          value: 'hfcs',
          resource_guid: package.guid,
        )
      end

      it 'presents the package as json' do
        links = {
          self: { href: "#{link_prefix}/v3/packages/#{package.guid}" },
          app: { href: "#{link_prefix}/v3/apps/#{package.app_guid}" }
        }

        expect(result[:guid]).to eq(package.guid)
        expect(result[:type]).to eq(package.type)
        expect(result[:state]).to eq(package.state)
        expect(result[:data][:error]).to eq(package.error)
        expect(result[:data][:checksum]).to eq({ type: 'sha256', value: 'sha256' })
        expect(result[:created_at]).to eq(package.created_at)
        expect(result[:updated_at]).to eq(package.updated_at)
        expect(result[:relationships][:app][:data][:guid]).to eq(package.app_guid)
        expect(result[:links]).to include(links)
        expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
        expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
      end

      context 'when the package type is bits' do
        let(:package) { VCAP::CloudController::PackageModel.make(type: 'bits') }

        it 'includes links to upload, download, and stage' do
          expect(result[:links][:upload][:href]).to eq("#{link_prefix}/v3/packages/#{package.guid}/upload")
          expect(result[:links][:upload][:method]).to eq('POST')

          expect(result[:links][:download][:href]).to eq("#{link_prefix}/v3/packages/#{package.guid}/download")
          expect(result[:metadata][:labels]).to eq('release' => 'stable', 'canberra.au/potato' => 'mashed')
          expect(result[:metadata][:annotations]).to eq('altitude' => '14,412', 'maize' => 'hfcs')
        end

        context 'when bits-service is enabled' do
          let(:bits_service_double) { double('bits_service') }
          let(:blob_double) { double('blob') }
          let(:bits_service_public_upload_url) { "https://some.public/signed/url/to/upload/package#{package.guid}" }

          before do
            VCAP::CloudController::Config.config.set(:bits_service, { enabled: true })

            allow_any_instance_of(CloudController::DependencyLocator).to receive(:package_blobstore).
              and_return(bits_service_double)
            allow(bits_service_double).to receive(:blob).and_return(blob_double)
            allow(blob_double).to receive(:public_upload_url).and_return(bits_service_public_upload_url)
          end

          context 'when show_bits_service_upload_link is true' do
            it 'includes links to upload to bits-service' do
              expect(result[:links][:upload][:href]).to eq(bits_service_public_upload_url)
              expect(result[:links][:upload][:method]).to eq('PUT')

              expect(result[:links][:download][:href]).to eq("#{link_prefix}/v3/packages/#{package.guid}/download")
            end
          end

          context 'when show_bits_service_upload_link is false' do
            let(:show_bits_service_upload_link) { false }

            it 'does NOT include links to upload to bits-service' do
              expect(result[:links]).not_to include(:upload)

              expect(result[:links][:download][:href]).to eq("#{link_prefix}/v3/packages/#{package.guid}/download")
            end
          end
        end
      end

      context 'when the package type is docker' do
        let(:package) do
          VCAP::CloudController::PackageModel.make(
            type: 'docker',
            docker_image: 'registry/image:latest',
            docker_username: 'jarjarbinks',
            docker_password: 'meesaPassword'
          )
        end

        it 'presents the docker information in the data section' do
          data = result[:data]
          expect(data[:image]).to eq('registry/image:latest')
          expect(data[:username]).to eq('jarjarbinks')
          expect(data[:password]).to eq('***')
        end

        it 'does not include upload or download links' do
          expect(result[:links]).not_to include(:upload)
          expect(result[:links]).not_to include(:download)
        end

        context 'when no docker credentials are present' do
          let(:package) do
            VCAP::CloudController::PackageModel.make(
              type: 'docker',
              docker_image: 'registry/image:latest',
            )
          end

          it 'displays null for username and password' do
            data = result[:data]
            expect(data[:image]).to eq('registry/image:latest')
            expect(data[:username]).to be_nil
            expect(data[:password]).to be_nil
          end
        end
      end

      context 'when the package type is not bits' do
        let(:package) { VCAP::CloudController::PackageModel.make(type: 'docker', docker_image: 'some-image') }

        it 'does NOT include a link to upload' do
          expect(result[:links][:upload]).to be_nil
        end
      end
    end
  end
end
