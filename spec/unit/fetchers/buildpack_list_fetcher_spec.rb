require 'spec_helper'
require 'fetchers/buildpack_list_fetcher'

module VCAP::CloudController
  RSpec.describe BuildpackListFetcher do
    let(:fetcher) { BuildpackListFetcher.new }

    describe '#fetch_all' do
      let!(:stack1) { Stack.make }
      let!(:stack2) { Stack.make }
      let!(:stack3) { Stack.make }

      let!(:buildpack1) { Buildpack.make(stack: stack1.name) }
      let!(:buildpack2) { Buildpack.make(stack: stack2.name) }
      let!(:buildpack3) { Buildpack.make(stack: stack3.name) }

      let(:message) { BuildpacksListMessage.from_params(filters) }
      subject { fetcher.fetch_all(message) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the buildpacks' do
          expect(subject).to match_array([buildpack1, buildpack2, buildpack3])
        end
      end

      context 'when the buildpacks are filtered' do
        let(:filters) { { names: [buildpack1.name, buildpack2.name], stacks: [stack1.name] } }

        it 'returns all of the desired buildpacks' do
          expect(subject).to include(buildpack1)
          expect(subject).to_not include(buildpack2)
        end
      end
    end
  end
end
