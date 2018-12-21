require 'spec_helper'
require 'fetchers/buildpack_list_fetcher'

module VCAP::CloudController
  RSpec.describe BuildpackListFetcher do
    let(:fetcher) { BuildpackListFetcher.new }

    describe '#fetch_all' do
      let!(:buildpack1) { Buildpack.make }
      let!(:buildpack2) { Buildpack.make }

      subject { fetcher.fetch_all }

      context 'when no filters are specified' do
        it 'fetches all the buildpacks' do
          expect(subject).to match_array([buildpack1, buildpack2])
        end
      end
    end
  end
end
