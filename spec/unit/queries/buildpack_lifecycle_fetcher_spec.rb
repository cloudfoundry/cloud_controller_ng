require 'spec_helper'
require 'queries/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  describe BuildpackLifecycleFetcher do
    let(:fetcher) { BuildpackLifecycleFetcher.new }

    describe '#fetch' do
      let(:stack) { Stack.make }
      let(:buildpack) { Buildpack.make }

      it 'returns the stack and buildpack' do
        returned_hash = fetcher.fetch(buildpack.name, stack.name)
        expect(returned_hash[:buildpack]).to eq(buildpack)
        expect(returned_hash[:stack]).to eq(stack)
      end

      context 'when the stack and buildpack are not found' do
        it 'returns nil for both' do
          returned_hash = fetcher.fetch('bogus-buildpack', 'bogus-stack')
          expect(returned_hash[:buildpack]).to be_nil
          expect(returned_hash[:stack]).to be_nil
        end
      end

      context 'when the stack and buildpack are nil' do
        it 'returns nil for both' do
          returned_hash = fetcher.fetch(nil, nil)
          expect(returned_hash[:buildpack]).to be_nil
          expect(returned_hash[:stack]).to be_nil
        end
      end
    end
  end
end
