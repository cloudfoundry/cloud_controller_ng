require 'spec_helper'
require 'fetchers/stack_list_fetcher'

module VCAP::CloudController
  RSpec.describe StackListFetcher do
    let(:fetcher) { StackListFetcher.new }

    describe '#fetch_all' do
      before do
        Stack.dataset.destroy
      end

      let!(:stack1) { Stack.make }
      let!(:stack2) { Stack.make }

      let(:message) { StacksListMessage.from_params(filters) }
      subject { fetcher.fetch_all(message) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the stacks' do
          expect(subject).to match_array([stack1, stack2])
        end
      end

      context 'when the stacks are filtered' do
        let(:filters) { { names: [stack1.name] } }

        it 'returns all of the desired stacks' do
          expect(subject).to include(stack1)
          expect(subject).to_not include(stack2)
        end
      end
    end
  end
end
