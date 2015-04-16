require 'spec_helper'
require 'actions/app_delete'

module VCAP::CloudController
  describe AppDelete do
    subject(:app_delete) { AppDelete.new(user.guid, user_email) }

    describe '#delete' do
      let!(:app_model) { AppModel.make }
      let!(:app_dataset) { app_model }
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
          expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_delete_request).with(
            app_model,
            app_model.space,
            user.guid,
            user_email
          )

          app_delete.delete(app_dataset)
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
