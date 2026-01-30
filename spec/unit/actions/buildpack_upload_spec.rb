require 'spec_helper'
require 'actions/buildpack_upload'

module VCAP::CloudController
  RSpec.describe BuildpackUpload do
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }
    let(:user_name) { 'user-name' }
    let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email, user_name: user_name) }

    subject(:buildpack_upload) { BuildpackUpload.new(user_audit_info) }

    describe '#upload_async' do
      let!(:buildpack) { VCAP::CloudController::Buildpack.create_from_hash({ name: 'upload_binary_buildpack', stack: nil, position: 0 }) }
      let(:message) { BuildpackUploadMessage.new({ 'bits_path' => '/tmp/path', 'bits_name' => 'buildpack.zip' }, VCAP::CloudController::Lifecycles::BUILDPACK) }
      let(:config) { Config.new({ name: 'local', index: '1' }) }

      before do
        allow(Buildpacks::StackNameExtractor).to receive(:extract_from_file).and_return('the-stack')
      end

      context 'when the buildpack and message are valid' do
        it 'enqueues and returns an upload job' do
          returned_job = nil
          expect do
            returned_job = buildpack_upload.upload_async(message:, buildpack:, config:)
          end.to change(Delayed::Job, :count).by(1)

          job = Delayed::Job.last
          expect(returned_job.delayed_job_guid).to eq(job.guid)
          expect(job.queue).to eq('cc-local-1')
          expect(job.handler).to include(buildpack.guid)
          expect(job.handler).to include('BuildpackBits')
        end

        it 'leaves the state as AWAITING_UPLOAD' do
          buildpack_upload.upload_async(message:, buildpack:, config:)
          expect(Buildpack.find(guid: buildpack.guid).state).to eq(Buildpack::CREATED_STATE)
        end

        it 'uses the right path and filename' do
          expect(Jobs::V3::BuildpackBits).to receive(:new).with(
            buildpack.guid,
            '/tmp/path',
            'buildpack.zip',
            user_audit_info,
            message.audit_hash
          ).and_call_original
          buildpack_upload.upload_async(message:, buildpack:, config:)
        end
      end
    end
  end
end
