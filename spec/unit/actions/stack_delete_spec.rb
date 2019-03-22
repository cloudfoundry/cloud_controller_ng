require 'spec_helper'
require 'actions/stack_delete'

module VCAP::CloudController
  RSpec.describe StackDelete do
    subject(:stack_delete) { StackDelete.new }

    describe '#delete' do
      context 'when the stack exists' do
        let!(:stack) { Stack.make }

        it 'deletes the stack record' do
          expect {
            stack_delete.delete(stack)
          }.to change { Stack.count }.by(-1)
          expect { stack.refresh }.to raise_error(Sequel::Error, 'Record not found')
        end

        it 'deletes associated labels' do
          label = StackLabelModel.make(resource_guid: stack.guid)
          expect {
            stack_delete.delete(stack)
          }.to change { StackLabelModel.count }.by(-1)
          expect(label.exists?).to be_falsey
          expect(stack.exists?).to be_falsey
        end

        it 'deletes associated annotations' do
          annotation = StackAnnotationModel.make(resource_guid: stack.guid)
          expect {
            stack_delete.delete(stack)
          }.to change { StackAnnotationModel.count }.by(-1)
          expect(annotation.exists?).to be_falsey
          expect(stack.exists?).to be_falsey
        end

        context 'when there are apps associated with the stack' do
          let!(:app) { AppModel.make }

          before do
            stack.apps << app
          end

          it 'does not delete the stack and raises an error' do
            expect {
              stack_delete.delete(stack)
            }.to raise_error(Stack::AppsStillPresentError)
            expect(stack.exists?).to be_truthy
          end
        end
      end
    end
  end
end
