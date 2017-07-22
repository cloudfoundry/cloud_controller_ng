require 'spec_helper'
require 'presenters/v3/package_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe PackagePresenter do
    describe '#to_hash' do
      let(:result) { PackagePresenter.new(package).to_hash }
      let(:package) { VCAP::CloudController::PackageModel.make(type: 'package_type', sha256_checksum: 'sha256') }

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
        expect(result[:links]).to include(links)
      end

      context 'when the package type is bits' do
        let(:package) { VCAP::CloudController::PackageModel.make(type: 'bits') }

        it 'includes links to upload, download, and stage' do
          expect(result[:links][:upload][:href]).to eq("#{link_prefix}/v3/packages/#{package.guid}/upload")
          expect(result[:links][:upload][:method]).to eq('POST')

          expect(result[:links][:download][:href]).to eq("#{link_prefix}/v3/packages/#{package.guid}/download")
          expect(result[:links][:download][:method]).to eq('GET')
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
