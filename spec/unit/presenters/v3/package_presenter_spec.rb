require 'spec_helper'
require 'presenters/v3/package_presenter'

module VCAP::CloudController
  describe PackagePresenter do
    describe '#present_json' do
      it 'presents the package as json' do
        package = PackageModel.make(type: 'package_type', created_at: Time.at(1), updated_at: Time.at(2))

        json_result = PackagePresenter.new.present_json(package)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(package.guid)
        expect(result['type']).to eq(package.type)
        expect(result['state']).to eq(package.state)
        expect(result['data']['error']).to eq(package.error)
        expect(result['data']['hash']).to eq({ 'type' => 'sha1', 'value' => package.package_hash })
        expect(result['created_at']).to eq('1970-01-01T00:00:01Z')
        expect(result['updated_at']).to eq('1970-01-01T00:00:02Z')
        expect(result['links']).to include('self')
        expect(result['links']).to include('app')
      end

      context 'when the package type is bits' do
        let(:package) { PackageModel.make(type: 'bits', url: 'foobar') }

        it 'includes links to upload and stage' do
          json_result = PackagePresenter.new.present_json(package)
          result      = MultiJson.load(json_result)

          expect(result['links']['upload']['href']).to eq("/v3/packages/#{package.guid}/upload")
          expect(result['links']['upload']['method']).to eq('POST')

          expect(result['links']['stage']['href']).to eq("/v3/packages/#{package.guid}/droplets")
          expect(result['links']['stage']['method']).to eq('POST')
        end
      end

      context 'when the package type is docker' do
        let(:package) do
          PackageModel.make(type: 'docker')
        end

        let!(:data_model) do
          PackageDockerDataModel.create({
              image: 'registry/image:latest',
              package: package
            })
        end

        it 'presents the docker information in the data section' do
          json_result = PackagePresenter.new.present_json(package)
          result      = MultiJson.load(json_result)
          data        = result['data']

          expect(data['image']).to eq data_model.image
        end

        it 'includes links to stage' do
          json_result = PackagePresenter.new.present_json(package)
          result      = MultiJson.load(json_result)

          expect(result['links']['stage']['href']).to eq("/v3/packages/#{package.guid}/droplets")
          expect(result['links']['stage']['method']).to eq('POST')
        end
      end

      context 'when the package type is not bits' do
        let(:package) { PackageModel.make(type: 'docker', url: 'foobar') }

        it 'does NOT include a link to upload' do
          json_result = PackagePresenter.new.present_json(package)
          result      = MultiJson.load(json_result)

          expect(result['links']['upload']).to be_nil
        end
      end
    end

    describe '#present_json_list' do
      let(:pagination_presenter) { double(:pagination_presenter) }
      let(:package1) { PackageModel.make }
      let(:package2) { PackageModel.make }
      let(:packages) { [package1, package2] }
      let(:presenter) { PackagePresenter.new(pagination_presenter) }
      let(:page) { 1 }
      let(:per_page) { 1 }
      let(:options) { { page: page, per_page: per_page } }
      let(:total_results) { 2 }
      let(:paginated_result) { PaginatedResult.new(packages, total_results, PaginationOptions.new(options)) }
      before do
        allow(pagination_presenter).to receive(:present_pagination_hash) do |_, url|
          "pagination-#{url}"
        end
      end

      it 'presents the packages as a json array under resources' do
        json_result = presenter.present_json_list(paginated_result, 'potato')
        result      = MultiJson.load(json_result)

        guids = result['resources'].collect { |package_json| package_json['guid'] }
        expect(guids).to eq([package1.guid, package2.guid])
      end

      it 'includes pagination section' do
        json_result = presenter.present_json_list(paginated_result, 'bazooka')
        result      = MultiJson.load(json_result)

        expect(result['pagination']).to eq('pagination-bazooka')
      end
    end
  end
end
