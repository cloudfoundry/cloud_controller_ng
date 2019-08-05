require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe AppApplyManifestActionJob, job_context: :worker do
      let(:user) { User.make(admin: true) }
      let(:apply_manifest_action) { instance_double(AppApplyManifest) }
      let(:app) { AppModel.make(name: Sham.guid) }
      let(:parsed_app_manifest) { AppManifestMessage.create_from_yml({ name: 'blah', instances: 4, routes: [{ route: 'foo.example.com' }] }, {}) }
      subject(:job) { AppApplyManifestActionJob.new(app.guid, parsed_app_manifest, apply_manifest_action) }

      before do
        allow(apply_manifest_action).to receive(:apply).and_return([])
      end

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:apply_manifest_job)
      end

      it 'calls the apply action' do
        job.perform

        expect(apply_manifest_action).to have_received(:apply).with(app.guid, parsed_app_manifest)
      end

      context 'when the apply manifest action fails' do
        before do
          allow(apply_manifest_action).to receive(:apply).and_raise(StandardError)
        end

        it 'bubbles up the error' do
          expect { job.perform }.to raise_error(StandardError)
        end
      end

      context 'when an AppApplyManifest::NoDefaultDomain error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(AppApplyManifest::NoDefaultDomain, 'some sub-action failed!')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /some sub-action failed!/)
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

      context 'when a ProcessCreate::InvalidProcess error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(ProcessCreate::InvalidProcess, 'Invalid health check type')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid health check type/)
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

      context 'when a SidecarCreate::InvalidSidecar error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(SidecarCreate::InvalidSidecar, 'command presence, command is not present')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /command presence, command is not present/)
        end
      end

      context 'when a SidecarUpdate::InvalidSidecar error occurs' do
        it 'wraps the error in an ApiError' do
          allow(apply_manifest_action).to receive(:apply).and_raise(SidecarUpdate::InvalidSidecar, 'Invalid field on sidecar')
          expect {
            job.perform
          }.to raise_error(CloudController::Errors::ApiError, /Invalid field on sidecar/)
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

      describe '#resource_type' do
        it 'returns a display name' do
          expect(job.resource_type).to eq('app')
        end
      end

      describe '#display_name' do
        it 'returns a display name for this action' do
          expect(job.display_name).to eq('app.apply_manifest')
        end
      end

      describe '#resource_guid' do
        it 'returns the given app guid' do
          expect(job.resource_guid).to eq(app.guid)
        end
      end
    end
  end
end
