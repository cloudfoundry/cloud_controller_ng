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
      let!(:buildpack4) { Buildpack.make(stack: stack1.name) }
      let!(:buildpack_without_stack) { Buildpack.make(stack: nil) }

      let(:message) { BuildpacksListMessage.from_params(filters) }

      subject { fetcher.fetch_all(message) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the buildpacks' do
          expect(subject).to match_array([
            buildpack1,
            buildpack2,
            buildpack3,
            buildpack4,
            buildpack_without_stack
          ])
        end
      end

      context 'when filtering by name, stack, and label' do
        let(:filters) do
          {
            'names' => "#{buildpack1.name},#{buildpack2.name},#{buildpack4.name}",
            'stacks' => stack1.name,
            'label_selector' => 'key=value'
          }
        end
        let!(:label) { BuildpackLabelModel.make(resource_guid: buildpack1.guid, key_name: 'key', value: 'value') }

        it 'returns all of the desired buildpacks' do
          expect(subject).to match_array([buildpack1])
        end
      end

      context 'when filtering by null stack' do
        let(:filters) do
          { 'stacks' => '' }
        end

        it 'returns all of the desired buildpacks' do
          expect(subject).to match_array([buildpack_without_stack])
        end
      end

      context 'when filtering by stack name or null stack' do
        let(:filters) do
          { 'stacks' => "#{stack2.name}," }
        end

        it 'returns all of the desired buildpacks' do
          expect(subject).to match_array([buildpack2, buildpack_without_stack])
        end
      end
    end
  end
end
