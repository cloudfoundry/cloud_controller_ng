require 'spec_helper'
require 'actions/stack_delete'

module VCAP::CloudController
  RSpec.describe StackDelete do
    subject(:stack_delete) { StackDelete.new }

    describe '#delete' do
      context 'when the stack exists' do
        let!(:stack) { Stack.make }

        it 'deletes the stack record' do
          expect do
            stack_delete.delete(stack)
          end.to change(Stack, :count).by(-1)
          expect { stack.refresh }.to raise_error(Sequel::Error, 'Record not found')
        end

        it 'deletes associated labels' do
          label = StackLabelModel.make(resource_guid: stack.guid)
          expect do
            stack_delete.delete(stack)
          end.to change(StackLabelModel, :count).by(-1)
          expect(label).not_to exist
          expect(stack).not_to exist
        end

        it 'deletes associated annotations' do
          annotation = StackAnnotationModel.make(resource_guid: stack.guid)
          expect do
            stack_delete.delete(stack)
          end.to change(StackAnnotationModel, :count).by(-1)
          expect(annotation).not_to exist
          expect(stack).not_to exist
        end

        context 'when there are apps associated with the stack' do
          let!(:app) { AppModel.make }

          before do
            stack.apps << app
          end

          it 'does not delete the stack and raises an error' do
            expect do
              stack_delete.delete(stack)
            end.to raise_error(Stack::AppsStillPresentError)
            expect(stack).to exist
          end
        end
      end
    end
  end
end
