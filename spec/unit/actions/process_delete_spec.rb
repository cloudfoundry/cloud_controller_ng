require 'spec_helper'
require 'actions/process_delete'

module VCAP::CloudController
  RSpec.describe ProcessDelete do
    subject(:process_delete) { ProcessDelete.new(user_audit_info) }
    let(:user_audit_info) { instance_double(UserAuditInfo).as_null_object }
    let(:space) { create(:space) }
    let(:app) { create(:app_model, space:) }

    describe '#delete' do
      context 'when the process exists' do
        let!(:process) { create(:process_model, app: app, type: 'potato') }

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
          label = create(:process_label_model, resource_guid: process.guid, key_name: 'test1', value: 'bommel')
          expect do
            process_delete.delete([process])
          end.to change(ProcessLabelModel, :count).by(-1)
          expect(label).not_to exist
          expect(process).not_to exist
        end

        it 'deletes associated annotations' do
          annotation = create(:process_annotation_model, resource_guid: process.guid, key_name: 'test1', value: 'bommel')
          expect do
            process_delete.delete([process])
          end.to change(ProcessAnnotationModel, :count).by(-1)
          expect(annotation).not_to exist
          expect(process).not_to exist
        end
      end

      context 'when deleting multiple' do
        let!(:process1) { create(:process_model, :process, app:) }
        let!(:process2) { create(:process_model, :process, app:) }

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
