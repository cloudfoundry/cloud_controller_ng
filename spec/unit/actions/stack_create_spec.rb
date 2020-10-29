require 'spec_helper'
require 'actions/stack_create'
require 'messages/stack_create_message'

module VCAP::CloudController
  RSpec.describe StackCreate do
    describe 'create' do
      it 'creates a stack' do
        message = VCAP::CloudController::StackCreateMessage.new(
          name: 'the-name',
          description: 'the-description',
          metadata: {
            labels: {
              release: 'stable',
              'seriouseats.com/potato' => 'mashed'
            },
            annotations: {
              tomorrow: 'land',
              backstreet: 'boys'
            }
          }
        )
        stack = StackCreate.new.create(message)

        expect(stack.name).to eq('the-name')
        expect(stack.description).to eq('the-description')

        expect(stack).to have_labels(
          { prefix: 'seriouseats.com', key: 'potato', value: 'mashed' },
          { prefix: nil, key: 'release', value: 'stable' }
        )
        expect(stack).to have_annotations(
          { key: 'tomorrow', value: 'land' },
          { key: 'backstreet', value: 'boys' }
        )
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::Stack).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          message = VCAP::CloudController::StackCreateMessage.new(name: 'foobar')
          expect {
            StackCreate.new.create(message)
          }.to raise_error(StackCreate::Error, 'blork is busted')
        end
      end

      context 'when it is a uniqueness error' do
        let(:name) { 'Olsen' }

        before do
          VCAP::CloudController::Stack.create(name: name)
        end

        it 'raises a human-friendly error' do
          message = VCAP::CloudController::StackCreateMessage.new(name: name)
          expect {
            StackCreate.new.create(message)
          }.to raise_error(StackCreate::Error, 'Name must be unique')
        end
      end
    end
  end
end
