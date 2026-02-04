require 'spec_helper'
require 'jobs/v3/buildpack_bits'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe BuildpackBits, job_context: :api do
      let(:uploaded_path) { 'tmp/random-nginx-filename-1020930' }
      let(:filename) { 'buildpack.zip' }
      let!(:buildpack) { Buildpack.make }
      let(:buildpack_guid) { buildpack.guid }
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:user_name) { 'user-name' }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }
      let(:request_attrs) { { 'bits_name' => filename } }

      subject(:job) do
        BuildpackBits.new(buildpack_guid, uploaded_path, filename)
      end

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        it 'creates a blobstore client and performs' do
          uploader = instance_double(UploadBuildpack)
          expect(UploadBuildpack).to receive(:new).with(instance_of(CloudController::Blobstore::Client)).and_return(uploader)
          expect(uploader).to receive(:upload_buildpack).with(buildpack, uploaded_path, filename)
          expect(FileUtils).to receive(:rm_f).with(uploaded_path)
          job.perform
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:buildpack_bits)
        end

        context 'when user_audit_info is provided' do
          subject(:job) do
            BuildpackBits.new(buildpack_guid, uploaded_path, filename, user_audit_info, request_attrs)
          end

          it 'creates an audit event when upload is successful' do
            uploader = instance_double(UploadBuildpack)
            allow(UploadBuildpack).to receive(:new).and_return(uploader)
            allow(uploader).to receive(:upload_buildpack).and_return(true)
            allow(FileUtils).to receive(:rm_f)

            expect do
              job.perform
            end.to change(Event, :count).by(1)

            event = Event.last
            expect(event.values).to include(
              type: 'audit.buildpack.upload',
              actee: buildpack.guid,
              actee_type: 'buildpack',
              actee_name: buildpack.name,
              actor: user_audit_info.user_guid,
              actor_type: 'user',
              actor_name: user_audit_info.user_email,
              actor_username: user_audit_info.user_name,
              space_guid: '',
              organization_guid: ''
            )
            expect(event.metadata).to eq({ 'request' => request_attrs })
            expect(event.timestamp).to be
          end

          it 'does not create an audit event when upload fails' do
            uploader = instance_double(UploadBuildpack)
            allow(UploadBuildpack).to receive(:new).and_return(uploader)
            allow(uploader).to receive(:upload_buildpack).and_return(false)
            allow(FileUtils).to receive(:rm_f)

            expect do
              job.perform
            end.not_to change(Event, :count)
          end
        end

        context 'when user_audit_info is not provided' do
          it 'does not create an audit event' do
            uploader = instance_double(UploadBuildpack)
            allow(UploadBuildpack).to receive(:new).and_return(uploader)
            allow(uploader).to receive(:upload_buildpack).and_return(true)
            allow(FileUtils).to receive(:rm_f)

            expect do
              job.perform
            end.not_to change(Event, :count)
          end
        end
      end
    end
  end
end
