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
          app1.guid => NamedAppManifestMessage.create_from_yml({ name: app1.name, instances: 4, routes: [{ route: 'foo.example.com' }] }),
          app2.guid => NamedAppManifestMessage.create_from_yml({ name: app2.name, instances: 5 }),
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

      context 'when the apply manifest action fails' do
        before do
          allow(apply_manifest_action).to receive(:apply).and_raise(StandardError)
        end

        it 'bubbles up the error' do
          expect { job.perform }.to raise_error(StandardError)
        end
      end

      context 'when a ProcessScale::InvalidProcess error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).with(app2.guid, anything).and_raise(ProcessScale::InvalidProcess, 'maximum instance count exceeded')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /For application 'cut': maximum instance count exceeded/)
        end
      end

      context 'when an AppUpdate::InvalidApp error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(AppUpdate::InvalidApp, 'Specified unknown buildpack name')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /unknown buildpack name/)
        end
      end

      context 'when a ProcessUpdate::InvalidProcess error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(ProcessUpdate::InvalidProcess, 'Invalid health check type')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid health check type/)
        end
      end

      context 'when an AppPatchEnvironmentVariables::InvalidApp error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(AppPatchEnvironmentVariables::InvalidApp, 'Invalid env varz')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid env varz/)
        end
      end

      context 'when an ManifestRouteUpdate::InvalidRoute error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(ManifestRouteUpdate::InvalidRoute, 'Invalid route')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid route/)
        end
      end

      context 'when a Route::InvalidOrganizationRelation error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(Route::InvalidOrganizationRelation, 'Organization cannot use domain hello.there')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Organization cannot use domain hello\.there/)
        end
      end

      context 'when an ServiceBindingCreate::InvalidServiceBinding error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(ServiceBindingCreate::InvalidServiceBinding, 'Invalid binding name')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid binding name/)
        end

        context 'subclasses of InvalidServiceBinding' do
          it 'wraps the error in an ApiError' do
            [
              ServiceBindingCreate::ServiceInstanceNotBindable,
              ServiceBindingCreate::ServiceBrokerInvalidSyslogDrainUrl,
              ServiceBindingCreate::VolumeMountServiceDisabled,
              ServiceBindingCreate::SpaceMismatch
            ].each do |exception|
              allow(apply_manifest_action).to receive(:apply).and_raise(exception, 'Invalid binding name')
              expect {
                job.perform
              }.to raise_error(CloudController::Errors::ApiError, /Invalid binding name/)
            end
          end
        end
      end

      context 'when an RouteMappingCreate::SpaceMismatch error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(RouteMappingCreate::SpaceMismatch, 'space mismatch message')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /space mismatch message/)
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
