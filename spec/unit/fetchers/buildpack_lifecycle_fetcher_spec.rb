require 'spec_helper'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  RSpec.describe BuildpackLifecycleFetcher do
    let(:fetcher) { BuildpackLifecycleFetcher.new }

    describe '#fetch' do
      let!(:stack) { Stack.make }
      let!(:stack2) { Stack.make }

      let!(:buildpack) { Buildpack.make(name: 'buildpack-1', stack: stack.name) }
      let!(:buildpack2) { Buildpack.make(name: 'buildpack-2', stack: stack.name) }
      let!(:buildpack3) { Buildpack.make(name: 'buildpack-2', stack: stack2.name) }

      it 'returns the stack and buildpack for the given stack' do
        returned_hash = BuildpackLifecycleFetcher.fetch([buildpack2.name, buildpack.name, 'http://buildpack.example.com'], stack.name)
        expect(returned_hash[:stack]).to eq(stack)

        buildpack_infos = returned_hash[:buildpack_infos]
        expect(buildpack_infos.map(&:buildpack)).to eq(['buildpack-2', 'buildpack-1', 'http://buildpack.example.com'])
        expect(buildpack_infos.map(&:buildpack_record)).to eq([buildpack2, buildpack, nil])
      end

      context 'buildpacks with unknown stack exist' do
        context 'only buildpack with nil stack exists' do
          let!(:stack3) { Stack.make }
          let!(:buildpack4) { Buildpack.make(:nil_stack, name: 'buildpack-3') }

          it 'returns the stack and buildpack' do
            returned_hash = BuildpackLifecycleFetcher.fetch(['buildpack-3'], stack3.name)
            expect(returned_hash[:stack]).to eq(stack3)

            buildpack_infos = returned_hash[:buildpack_infos]
            expect(buildpack_infos.map(&:buildpack)).to eq(['buildpack-3'])
            expect(buildpack_infos.map(&:buildpack_record)).to eq([buildpack4])
          end
        end

        context 'buildpack with nil stack and matching stack both exist' do
          let!(:buildpack4) { Buildpack.make(:nil_stack, name: 'buildpack-2') }

          it 'chooses the buildpack with non-nil stack' do
            returned_hash = BuildpackLifecycleFetcher.fetch([buildpack2.name, buildpack.name, 'http://buildpack.example.com'], stack.name)
            expect(returned_hash[:stack]).to eq(stack)

            buildpack_infos = returned_hash[:buildpack_infos]
            expect(buildpack_infos.map(&:buildpack)).to eq(['buildpack-2', 'buildpack-1', 'http://buildpack.example.com'])
            expect(buildpack_infos.map(&:buildpack_record)).to eq([buildpack2, buildpack, nil])
          end
        end
      end

      context 'when the stack and buildpack are not found' do
        it 'returns nil for both' do
          returned_hash = BuildpackLifecycleFetcher.fetch(['bogus-buildpack'], 'bogus-stack')

          buildpack_infos = returned_hash[:buildpack_infos]
          expect(buildpack_infos.map(&:buildpack)).to eq(['bogus-buildpack'])
          expect(returned_hash[:stack]).to be_nil
          expect(buildpack_infos.map(&:buildpack_record)).to eq([nil])
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
