require 'spec_helper'
require 'actions/process_delete'

module VCAP::CloudController
  RSpec.describe ProcessDelete do
    subject(:process_delete) { described_class.new(user_guid, user_email) }
    let(:user_guid) { 'user-guid' }
    let(:user_email) { 'user@example.com' }
    let(:space) { Space.make }
    let(:app) { AppModel.make(space: space) }

    describe '#delete' do
      context 'when the process exists' do
        let!(:process) { App.make(app: app, space: space, type: 'potato') }

        it 'deletes the process record' do
          expect {
            process_delete.delete(process)
          }.to change { App.count }.by(-1)
          expect(process.exists?).to be_falsey
        end

        it 'creates an audit.app.process.delete event' do
          process_delete.delete(process)

          event = Event.last
          expect(event.type).to eq('audit.app.process.delete')
          expect(event.metadata['process_guid']).to eq(process.guid)
        end
      end

      context 'when deleting multiple' do
        let!(:process1) { AppFactory.make(app: app) }
        let!(:process2) { AppFactory.make(app: app) }

        it 'deletes the process record' do
          expect {
            process_delete.delete([process1, process2])
          }.to change { App.count }.by(-2)
          expect(process1.exists?).to be_falsey
          expect(process2.exists?).to be_falsey
        end
      end
    end
  end
end
