require 'spec_helper'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleFetcher do
    let(:fetcher) { BuildpackLifecycleFetcher.new }

    describe '#fetch' do
      let(:stack) { Stack.make }
      let!(:buildpack) { Buildpack.make(name: 'buildpack-1') }
      let!(:buildpack2) { Buildpack.make(name: 'buildpack-2') }

      it 'returns the stack and buildpack' do
        returned_hash = BuildpackLifecycleFetcher.fetch([buildpack2.name, buildpack.name, 'http://buildpack.example.com'], stack.name)
        expect(returned_hash[:stack]).to eq(stack)

        buildpack_infos = returned_hash[:buildpack_infos]
        expect(buildpack_infos.map(&:buildpack)).to eq(['buildpack-2', 'buildpack-1', 'http://buildpack.example.com'])
      end

      context 'when the stack and buildpack are not found' do
        it 'returns nil for both' do
          returned_hash = BuildpackLifecycleFetcher.fetch(['bogus-buildpack'], 'bogus-stack')

          buildpack_infos = returned_hash[:buildpack_infos]
          expect(buildpack_infos.map(&:buildpack)).to eq(['bogus-buildpack'])
          expect(returned_hash[:stack]).to be_nil
        end
      end

      context 'when the stack and buildpack are not present' do
        it 'returns empty values' do
          returned_hash = BuildpackLifecycleFetcher.fetch([], nil)
          expect(returned_hash[:buildpack_infos]).to be_empty
          expect(returned_hash[:stack]).to be_nil
        end
      end
    end
  end
end
