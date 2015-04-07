require 'spec_helper'
require 'actions/process_delete'

module VCAP::CloudController
  describe ProcessDelete do
    subject(:process_delete) { ProcessDelete.new(space, user, user_email) }

    describe '#delete' do
      context 'when the process exists' do
        let(:space) { Space.make }
        let!(:app_model) { AppModel.make(space_guid: space.guid) }
        let!(:process) { AppFactory.make(app_guid: app_model.guid) }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }

        it 'deletes the process record' do
          expect {
            process_delete.delete(process)
          }.to change { App.count }.by(-1)
          expect { process.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'creates an app audit event' do
          expect {
            process_delete.delete(process)
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.delete-request')
          expect(event.actee).to eq(process.guid)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(user_email)
        end
      end

      context 'when deleting multiple' do
        let(:space) { Space.make }
        let!(:app_model) { AppModel.make(space_guid: space.guid) }
        let!(:process1) { AppFactory.make(app_guid: app_model.guid) }
        let!(:process2) { AppFactory.make(app_guid: app_model.guid) }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }

        it 'deletes the process record' do
          expect {
            process_delete.delete([process1, process2])
          }.to change { App.count }.by(-2)
          expect { process1.refresh }.to raise_error Sequel::Error, 'Record not found'
          expect { process2.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end
    end
  end
end
