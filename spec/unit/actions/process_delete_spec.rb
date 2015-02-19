require 'spec_helper'
require 'actions/process_delete'

module VCAP::CloudController
  describe ProcessDelete do
    subject(:process_delete) { ProcessDelete.new }

    describe '#delete' do
      context 'when the process exists' do
        let!(:app_model) { AppModel.make }
        let!(:process) { AppFactory.make(app_guid: app_model.guid) }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }

        it 'deletes the process record' do
          expect {
            process_delete.delete(process, user, user_email)
          }.to change { App.count }.by(-1)
          expect { process.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'creates an app audit event' do
          expect {
            process_delete.delete(process, user, user_email)
          }.to change { Event.count }.by(1)
          event = Event.last
          expect(event.type).to eq('audit.app.delete-request')
          expect(event.actee).to eq(process.guid)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(user_email)
        end
      end
    end
  end
end
