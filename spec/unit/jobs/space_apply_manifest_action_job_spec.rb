require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe SpaceApplyManifestActionJob, job_context: :worker do
      let(:user) { User.make(admin: true) }
      let(:user_audit_info) { UserAuditInfo.new(user_email: 'user.email', user_guid: user.guid, user_name: 'user.name') }
      let(:apply_manifest_action) { instance_double(AppApplyManifest) }
      let(:space) { Space.make }
      let(:app1) { AppModel.make(name: 'steel', space: space) }
      let(:app2) { AppModel.make(name: 'cut', space: space) }
      let(:app_guid_message_hash) do
        {
          app1.guid => AppManifestMessage.create_from_yml({ name: app1.name, instances: 4, routes: [{ route: 'foo.example.com' }] }),
          app2.guid => AppManifestMessage.create_from_yml({ name: app2.name, instances: 5 }),
        }
      end

      subject(:job) { SpaceApplyManifestActionJob.new(space, app_guid_message_hash, apply_manifest_action, user_audit_info) }

      before do
        allow(apply_manifest_action).to receive(:apply).and_return([])
      end

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:apply_space_manifest_job)
      end

      it 'calls the specified actions' do
        job.perform

        expect(apply_manifest_action).to have_received(:apply).with(app1.guid, app_guid_message_hash.values[0])
        expect(apply_manifest_action).to have_received(:apply).with(app2.guid, app_guid_message_hash.values[1])
      end

      context 'when an unknown error is raised' do
        before do
          allow(apply_manifest_action).to receive(:apply).and_raise(StandardError, 'the specific error')
        end

        it 'bubbles up the error so an UnknownError can be generated for the user' do
          expect { job.perform }.to raise_error(StandardError, 'the specific error')
        end
      end

      [
        AppPatchEnvironmentVariables::InvalidApp,
        AppUpdate::InvalidApp,
        ManifestRouteUpdate::InvalidRoute,
        AppApplyManifest::NoDefaultDomain,
        ProcessCreate::InvalidProcess,
        ProcessScale::InvalidProcess,
        ProcessUpdate::InvalidProcess,
        Route::InvalidOrganizationRelation,
        AppApplyManifest::Error,
        AppApplyManifest::ServiceBindingError,
        SidecarCreate::InvalidSidecar,
        SidecarUpdate::InvalidSidecar,
        ProcessScale::SidecarMemoryLessThanProcessMemory,
      ].each do |klass|
        it "wraps a #{klass} in an ApiError" do
          allow(apply_manifest_action).to receive(:apply).
            with(app2.guid, anything).
            and_raise(klass, 'base msg')

          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /For application '#{app2.name}': base msg/)
        end
      end

      it 'annotates StructuredError with the app name' do
        allow(apply_manifest_action).to receive(:apply).
          with(app2.guid, anything).
          and_raise(StructuredError.new('base msg', 'source'))

        expect {
          job.perform
        }.to raise_error(StructuredError, /For application '#{app2.name}': base msg/)
      end

      context 'when a record goes missing' do
        before do
          allow(apply_manifest_action).to receive(:apply).
            and_raise(CloudController::Errors::NotFound.new_from_details('ResourceNotFound', 'something went missing'))
        end

        it 'wraps the message of the error' do
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::NotFound, /For application '#{app1.name}': something went missing/)
        end
      end

      context 'when an error occurs and the app no longer exists' do
        before do
          allow(apply_manifest_action).to receive(:apply).
            and_raise(AppUpdate::InvalidApp, 'something bad happened')
          app_guid_message_hash
          app1.destroy
        end

        it 'wraps the message of the error' do
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /^something bad happened/)
        end
      end

      describe '#resource_type' do
        it 'returns a display name' do
          expect(job.resource_type).to eq('space')
        end
      end

      describe '#display_name' do
        it 'returns a display name for this action' do
          expect(job.display_name).to eq('space.apply_manifest')
        end
      end

      describe '#resource_guid' do
        it 'returns the given app guid' do
          expect(job.resource_guid).to eq(space.guid)
        end
      end
    end
  end
end
