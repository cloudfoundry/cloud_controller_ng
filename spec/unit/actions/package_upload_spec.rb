require 'spec_helper'
require 'actions/package_upload'

module VCAP::CloudController
  describe PackageUpload do
    subject(:package_upload) { PackageUpload.new(user_guid, user_email) }
    let(:user_guid) { 'gooid' }
    let(:user_email) { 'utako.loves@cats.com' }

    describe '#upload' do
      let(:package) { PackageModel.make(type: 'bits') }
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { { name: 'local', index: '1' } }

      it 'enqueues a upload job' do
        expect {
          package_upload.upload(message, package, config)
        }.to change { Delayed::Job.count }.by(1)

        job = Delayed::Job.last
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(package.guid)
        expect(job.handler).to include('PackageBits')
      end

      it 'changes the state to pending' do
        package_upload.upload(message, package, config)
        expect(PackageModel.find(guid: package.guid).state).to eq(PackageModel::PENDING_STATE)
      end

      it 'creates an v3 audit event' do
        expect(Repositories::PackageEventRepository).to receive(:record_app_package_upload).with(
          instance_of(PackageModel),
          user_guid,
          user_email
        )

        package_upload.upload(message, package, config)
      end

      context 'when the package is invalid' do
        before do
          allow(package).to receive(:save).and_raise(Sequel::ValidationFailed.new('message'))
        end

        it 'raises InvalidPackage' do
          expect {
            package_upload.upload(message, package, config)
          }.to raise_error(PackageUpload::InvalidPackage)
        end
      end
    end
  end
end
