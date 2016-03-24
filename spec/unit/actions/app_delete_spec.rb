require 'spec_helper'
require 'actions/app_delete'

module VCAP::CloudController
  describe AppDelete do
    subject(:app_delete) { AppDelete.new(user.guid, user_email) }

    describe '#delete' do
      let!(:app) { AppModel.make }
      let!(:app_dataset) { app }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      it 'deletes the app record' do
        expect {
          app_delete.delete(app_dataset)
        }.to change { AppModel.count }.by(-1)
        expect(app.exists?).to be_falsey
      end

      it 'creates an audit event' do
        expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_delete_request).with(
          app,
          app.space,
          user.guid,
          user_email
        )

        app_delete.delete(app_dataset)
      end

      describe 'recursive deletion' do
        it 'deletes associated packages' do
          package = PackageModel.make(app_guid: app.guid)

          expect {
            app_delete.delete(app_dataset)
          }.to change { PackageModel.count }.by(-1)
          expect(package.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated droplets' do
          droplet = DropletModel.make(app_guid: app.guid)

          expect {
            app_delete.delete(app_dataset)
          }.to change { DropletModel.count }.by(-1)
          expect(droplet.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated processes' do
          process = App.make(app_guid: app.guid)

          expect {
            app_delete.delete(app_dataset)
          }.to change { App.count }.by(-1)
          expect(process.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated routes' do
          route_mapping = RouteMappingModel.make(app: app, route: Route.make)

          expect {
            app_delete.delete(app_dataset)
          }.to change { RouteMappingModel.count }.by(-1)
          expect(route_mapping.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes associated tasks' do
          task_model = TaskModel.make(app_guid: app.guid, name: 'task1', state: TaskModel::SUCCEEDED_STATE)

          expect {
            app_delete.delete(app_dataset)
          }.to change { TaskModel.count }.by(-1)
          expect(task_model.exists?).to be_falsey
          expect(app.exists?).to be_falsey
        end

        it 'deletes the buildpack caches' do
          delete_buildpack_cache_jobs = Delayed::Job.where("handler like '%BuildpackCacheDelete%'")
          expect { app_delete.delete(app_dataset) }.to change { delete_buildpack_cache_jobs.count }.by(1)
          job = delete_buildpack_cache_jobs.last

          expect(job.handler).to include(app.guid)
          expect(job.queue).to eq('cc-generic')
          expect(app.exists?).to be_falsey
        end
      end

      context 'when the app has associated service bindings' do
        let(:binding) { ServiceBindingModel.make }
        let(:app) { binding.app }

        it 'raises a meaningful error and does not delete the app' do
          expect {
            app_delete.delete(app)
          }.to raise_error(AppDelete::InvalidDelete, 'Please delete the service_bindings associations for your apps.')

          expect(app.exists?).to be_truthy
        end
      end
    end
  end
end
