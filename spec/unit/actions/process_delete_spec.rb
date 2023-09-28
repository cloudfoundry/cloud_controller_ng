require 'spec_helper'
require 'actions/process_delete'

module VCAP::CloudController
  RSpec.describe ProcessDelete do
    subject(:process_delete) { ProcessDelete.new(user_audit_info) }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }
    let(:space) { Space.make }
    let(:app) { AppModel.make(space:) }

    describe '#delete' do
      context 'when the process exists' do
        let!(:process) { ProcessModel.make(app: app, type: 'potato') }

        it 'deletes the process record' do
          expect do
            process_delete.delete(process)
          end.to change(ProcessModel, :count).by(-1)
          expect(process).not_to exist
        end

        it 'creates an audit.app.process.delete event' do
          process_delete.delete(process)

          event = Event.last
          expect(event.type).to eq('audit.app.process.delete')
          expect(event.metadata['process_guid']).to eq(process.guid)
        end

        it 'deletes associated labels' do
          label = ProcessLabelModel.make(resource_guid: process.guid)
          expect do
            process_delete.delete([process])
          end.to change(ProcessLabelModel, :count).by(-1)
          expect(label).not_to exist
          expect(process).not_to exist
        end

        it 'deletes associated annotations' do
          annotation = ProcessAnnotationModel.make(resource_guid: process.guid)
          expect do
            process_delete.delete([process])
          end.to change(ProcessAnnotationModel, :count).by(-1)
          expect(annotation).not_to exist
          expect(process).not_to exist
        end
      end

      context 'when deleting multiple' do
        let!(:process1) { ProcessModel.make(:process, app:) }
        let!(:process2) { ProcessModel.make(:process, app:) }

        it 'deletes the process record' do
          expect do
            process_delete.delete([process1, process2])
          end.to change(ProcessModel, :count).by(-2)
          expect(process1).not_to exist
          expect(process2).not_to exist
        end
      end
    end
  end
end
