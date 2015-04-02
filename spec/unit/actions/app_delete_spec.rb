require 'spec_helper'
require 'actions/app_delete'

module VCAP::CloudController
  describe AppDelete do
    subject(:app_delete) { AppDelete.new(user, user_email) }

    describe '#delete' do
      let!(:app_model) { AppModel.make }
      let!(:app_dataset) { AppModel.where(guid: app_model.guid) }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      context 'when the app exists' do
        it 'deletes the app record' do
          expect {
            app_delete.delete(app_dataset)
          }.to change { AppModel.count }.by(-1)
          expect { app_model.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'creates an audit event' do
          app_delete.delete(app_dataset)
          event = Event.last
          expect(event.type).to eq('audit.app.delete')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_name).to eq(user_email)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee).to eq(app_model.guid)
        end

        context 'when the app has associated routes' do
          before do
            app_model.add_route(Route.make)
            app_model.add_route(Route.make)
          end

          it 'removes the association and deletes the app' do
            expect(app_model.routes.count).to eq(2)
            expect {
              app_delete.delete(app_dataset)
            }.to change { AppModel.count }.by(-1)
            expect { app_model.refresh }.to raise_error Sequel::Error, 'Record not found'
          end
        end
      end

      describe 'recursive deletion' do
        it 'deletes associated packages' do
          package = PackageModel.make(app_guid: app_model.guid)

          expect {
            app_delete.delete(app_dataset)
          }.to change { PackageModel.count }.by(-1)
          expect { package.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated droplets' do
          droplet = DropletModel.make(app_guid: app_model.guid)

          expect {
            app_delete.delete(app_dataset)
          }.to change { DropletModel.count }.by(-1)
          expect { droplet.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'deletes associated processes' do
          process = App.make(app_guid: app_model.guid)

          expect {
            app_delete.delete(app_dataset)
          }.to change { App.count }.by(-1)
          expect { process.refresh }.to raise_error Sequel::Error, 'Record not found'
        end
      end
    end
  end
end
