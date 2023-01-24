require 'spec_helper'
require 'fetchers/stack_list_fetcher'

module VCAP::CloudController
  RSpec.describe StackListFetcher do
    let(:stack_config_file) { File.join(Paths::FIXTURES, 'config/stacks.yml') }
    let(:default_stack_name) { 'default-stack-name' }
    let(:fetcher) { StackListFetcher }

    before { VCAP::CloudController::Stack.configure(stack_config_file) }

    describe '#fetch_all' do
      before do
        Stack.dataset.destroy
      end

      let!(:stack1) { Stack.make }
      let!(:stack2) { Stack.make(name: default_stack_name) }

      let(:message) { StacksListMessage.from_params(filters) }
      subject { fetcher.fetch_all(message) }

      context 'when no filters are specified' do
        let(:filters) { {} }

        it 'fetches all the stacks' do
          expect(subject).to match_array([stack1, stack2])
        end
      end

      context 'when the stacks are filtered by name' do
        let(:filters) { { names: [stack1.name] } }

        it 'returns all of the desired stacks' do
          expect(subject).to include(stack1)
          expect(subject).to_not include(stack2)
        end
      end

      context 'when the stacks are filtered by default-ness' do
        context 'when true' do
          let(:filters) { { default: 'true' } }

          it 'returns all of the desired stacks' do
            expect(subject).to_not include(stack1)
            expect(subject).to include(stack2)
          end
        end

        context 'when false' do
          let(:filters) { { default: 'false' } }

          it 'returns all of the desired stacks' do
            expect(subject).to include(stack1)
            expect(subject).to_not include(stack2)
          end
        end
      end

      context 'when a label_selector is provided' do
        let(:message) { StacksListMessage.from_params({ 'label_selector' => 'key=value' }) }
        let!(:stack1label) { StackLabelModel.make(key_name: 'key', value: 'value', stack: stack1) }
        let!(:stack2label) { StackLabelModel.make(key_name: 'key2', value: 'value2', stack: stack2) }

        it 'returns the correct set of stacks' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(stack1)
        end
      end
    end
  end
end
