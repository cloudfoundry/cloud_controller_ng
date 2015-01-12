require 'spec_helper'
require 'presenters/v3/package_presenter'

module VCAP::CloudController
  describe PackagePresenter do
    describe '#present_json' do
      it 'presents the package as json' do
        package = PackageModel.make(type: 'package_type', url: 'foobar')

        json_result = PackagePresenter.new.present_json(package)
        result      = MultiJson.load(json_result)

        expect(result['guid']).to eq(package.guid)
        expect(result['type']).to eq(package.type)
        expect(result['state']).to eq(package.state)
        expect(result['error']).to eq(package.error)
        expect(result['hash']).to eq(package.package_hash)
        expect(result['url']).to eq(package.url)
        expect(result['created_at']).to eq(package.created_at.as_json)
        expect(result['_links']).to include('self')
        expect(result['_links']).to include('space')
      end

      context 'when the package type is bits' do
        let(:package) { PackageModel.make(type: 'bits', url: 'foobar') }

        it 'includes a link to upload' do
          json_result = PackagePresenter.new.present_json(package)
          result      = MultiJson.load(json_result)

          expect(result['_links']['upload']['href']).to eq("/v3/packages/#{package.guid}/upload")
        end
      end
    end
  end
end
