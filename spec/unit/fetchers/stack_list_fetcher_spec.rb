require 'spec_helper'
require 'fetchers/stack_list_fetcher'

module VCAP::CloudController
  RSpec.describe StackListFetcher do
    let!(:fetcher) { StackListFetcher.new }

    describe '#fetch_all' do
      before { VCAP::CloudController::Stack.dataset.destroy }

      let!(:stack1) { VCAP::CloudController::Stack.make }
      let!(:stack2) { VCAP::CloudController::Stack.make }
      let!(:stack3) { VCAP::CloudController::Stack.make }
      let!(:stack4) { VCAP::CloudController::Stack.make }
      it 'fetches all the stacks' do
        all_stacks = fetcher.fetch_all
        expect(all_stacks.count).to eq(4)

        expect(all_stacks).to match_array([
          stack1, stack2, stack3, stack4
        ])
      end
    end
  end
end
