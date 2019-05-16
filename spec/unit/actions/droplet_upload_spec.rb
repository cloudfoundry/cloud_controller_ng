require 'spec_helper'
require 'actions/droplet_upload'

module VCAP::CloudController
  RSpec.describe DropletUpload do
    subject(:droplet_upload) { DropletUpload.new }

    describe '#upload_async' do
      let(:droplet) { DropletModel.make }
      let(:message) { DropletUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { Config.new({ name: 'local', index: '1' }) }
      let(:user_guid) { 'gooid' }
      let(:user_email) { 'utako.loves@cats.com' }

      it 'enqueues and returns an upload job' do
        returned_job = nil
        expect {
          returned_job = droplet_upload.upload_async(message: message, droplet: droplet, config: config)
        }.to change { Delayed::Job.count }.by(1)

        job = Delayed::Job.last
        expect(returned_job.delayed_job_guid).to eq(job.guid)
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(droplet.guid)
        expect(job.handler).to include('DropletUpload')
      end

      it 'changes the state to processing upload' do
        droplet_upload.upload_async(message: message, droplet: droplet, config: config)
        expect(DropletModel.find(guid: droplet.guid).state).to eq(DropletModel::PROCESSING_UPLOAD_STATE)
      end
    end
  end
end
