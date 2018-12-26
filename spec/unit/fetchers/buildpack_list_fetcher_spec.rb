require 'spec_helper'
require 'fetchers/buildpack_list_fetcher'

module VCAP::CloudController
  RSpec.describe BuildpackListFetcher do
    let(:fetcher) { BuildpackListFetcher.new }

    describe '#fetch_all' do
      let!(:buildpack1) { Buildpack.make }
      let!(:buildpack2) { Buildpack.make }

      let(:message) { BuildpacksListMessage.from_params(filters) }
      subject { fetcher.fetch_all(message) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the buildpacks' do
          expect(subject).to match_array([buildpack1, buildpack2])
        end
      end

      context 'when the stacks are filtered' do
        let(:filters) { { names: [buildpack1.name] } }

        it 'returns all of the desired stacks' do
          expect(subject).to include(buildpack1)
          expect(subject).to_not include(buildpack2)
        end
      end
    end
  end
end
