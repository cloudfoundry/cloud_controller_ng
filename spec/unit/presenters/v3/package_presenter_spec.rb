require 'spec_helper'
require 'presenters/v3/package_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe PackagePresenter do
    describe '#to_hash' do
      let(:result) { PackagePresenter.new(package).to_hash }
      let(:package) { VCAP::CloudController::PackageModel.make(type: 'package_type', created_at: Time.at(1), updated_at: Time.at(2)) }

      it 'presents the package as json' do
        expect(result[:guid]).to eq(package.guid)
        expect(result[:type]).to eq(package.type)
        expect(result[:state]).to eq(package.state)
        expect(result[:data][:error]).to eq(package.error)
        expect(result[:data][:hash]).to eq({ type: 'sha1', value: package.package_hash })
        expect(result[:created_at]).to eq('1970-01-01T00:00:01Z')
        expect(result[:updated_at]).to eq('1970-01-01T00:00:02Z')
        expect(result[:links]).to include(:self)
        expect(result[:links]).to include(:app)
      end

      context 'when the package type is bits' do
        let(:package) { VCAP::CloudController::PackageModel.make(type: 'bits', url: 'foobar') }

        it 'includes links to upload and stage' do
          expect(result[:links][:upload][:href]).to eq("/v3/packages/#{package.guid}/upload")
          expect(result[:links][:upload][:method]).to eq('POST')

          expect(result[:links][:stage][:href]).to eq("/v3/packages/#{package.guid}/droplets")
          expect(result[:links][:stage][:method]).to eq('POST')
        end
      end

      context 'when the package type is docker' do
        let(:package) do
          VCAP::CloudController::PackageModel.make(type: 'docker')
        end

        let!(:data_model) do
          VCAP::CloudController::PackageDockerDataModel.create({
              image: 'registry/image:latest',
              package: package
            })
        end

        it 'presents the docker information in the data section' do
          data = result[:data]
          expect(data[:image]).to eq data_model.image
        end

        it 'includes links to stage' do
          expect(result[:links][:stage][:href]).to eq("/v3/packages/#{package.guid}/droplets")
          expect(result[:links][:stage][:method]).to eq('POST')
        end
      end

      context 'when the package type is not bits' do
        let(:package) { VCAP::CloudController::PackageModel.make(type: 'docker', url: 'foobar') }

        it 'does NOT include a link to upload' do
          expect(result[:links][:upload]).to be_nil
        end
      end
    end
  end
end
