require 'spec_helper'
require 'actions/droplet_upload'

module VCAP::CloudController
  RSpec.describe DropletUpload do
    subject(:droplet_upload) { DropletUpload.new }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user-email', user_guid: 'user_guid') }

    describe '#upload_async' do
      let(:droplet) { DropletModel.make }
      let(:message) { DropletUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { Config.new({ name: 'local', index: '1' }) }
      let(:user_guid) { 'gooid' }
      let(:user_email) { 'utako.loves@cats.com' }

      it 'enqueues and returns an upload job' do
        returned_job = nil
        expect {
          returned_job = droplet_upload.upload_async(message: message, droplet: droplet, config: config, user_audit_info: user_audit_info)
        }.to change { Delayed::Job.count }.by(1)

        job = Delayed::Job.last
        expect(returned_job.delayed_job_guid).to eq(job.guid)
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(droplet.guid)
        expect(job.handler).to include('DropletUpload')
      end

      it 'changes the state to processing upload' do
        droplet_upload.upload_async(message: message, droplet: droplet, config: config, user_audit_info: user_audit_info)
        expect(DropletModel.find(guid: droplet.guid).state).to eq(DropletModel::PROCESSING_UPLOAD_STATE)
      end

      it 'records an audit event for the upload' do
        expect(Repositories::DropletEventRepository).to receive(:record_upload).with(
          droplet,
          user_audit_info,
          droplet.app.name,
          droplet.app.space_guid,
          droplet.app.space.organization_guid
        )

        droplet_upload.upload_async(message: message, droplet: droplet, config: config, user_audit_info: user_audit_info)
      end
    end
  end
end
