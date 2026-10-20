require 'spec_helper'
require 'actions/package_upload'

module VCAP::CloudController
  RSpec.describe PackageUpload do
    subject(:package_upload) { PackageUpload.new }

    before do
      allow(File).to receive(:rename)
    end

    describe '#upload_async' do
      let(:package) { create(:package_model, type: 'bits') }
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { Config.new({ name: 'local', index: '1' }) }
      let(:user_guid) { 'gooid' }
      let(:user_email) { 'utako.loves@cats.com' }
      let(:user_audit_info) { UserAuditInfo.new(user_email:, user_guid:) }

      it 'enqueues a pollable upload job and returns the pollable job' do
        expect(SecureRandom).to receive(:alphanumeric).with(10).and_return('S8baxMJnPl')

        returned_job = nil
        expect do
          returned_job = package_upload.upload_async(message:, package:, config:, user_audit_info:)
        end.to change(Delayed::Job, :count).by(1)

        job = Delayed::Job.last
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(package.guid)
        expect(job.handler).to include('/tmp/path-S8baxMJnPl')
        expect(job.handler).to include('PackageBits')

        expect(returned_job).to be_a(PollableJobModel)
        expect(returned_job.delayed_job_guid).to eq(job.guid)
        expect(returned_job.operation).to eq('package.upload')
        expect(returned_job.resource_guid).to eq(package.guid)
        expect(returned_job.resource_type).to eq('package')
      end

      it 'changes the state to pending' do
        package_upload.upload_async(message:, package:, config:, user_audit_info:)
        expect(PackageModel.find(guid: package.guid).state).to eq(PackageModel::PENDING_STATE)
      end

      it 'creates an audit event' do
        expect(Repositories::PackageEventRepository).to receive(:record_app_package_upload).with(
          instance_of(PackageModel),
          user_audit_info
        )

        package_upload.upload_async(message:, package:, config:, user_audit_info:)
      end

      context 'when dynamic job priorities are enabled' do
        before do
          TestConfig.config[:jobs][:enable_dynamic_job_priorities] = true
          security_context = double(current_user_email: user_email, current_user_name: nil, current_user: double(guid: user_guid))
          stub_const('VCAP::CloudController::SecurityContext', security_context)
        end

        it 'deprioritizes the upload by the number of the user\'s active jobs' do
          # Two existing active pollable jobs for the same user
          2.times do |i|
            PollableJobModel.create(state: PollableJobModel::PROCESSING_STATE, user_guid: user_guid, delayed_job_guid: "existing-#{i}")
          end

          package_upload.upload_async(message:, package:, config:, user_audit_info:)

          expect(Delayed::Job.last.priority).to eq(2)
        end

        it 'does not deprioritize when the user has no active jobs' do
          package_upload.upload_async(message:, package:, config:, user_audit_info:)
          expect(Delayed::Job.last.priority).to eq(0)
        end
      end

      context 'when the package is invalid' do
        before do
          allow(package).to receive(:save).and_raise(Sequel::ValidationFailed.new('message'))
        end

        it 'raises InvalidPackage' do
          expect do
            package_upload.upload_async(message:, package:, config:, user_audit_info:)
          end.to raise_error(PackageUpload::InvalidPackage)
        end
      end
    end

    describe '#upload_async_without_event' do
      let(:package) { create(:package_model, type: 'bits') }
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { Config.new({ name: 'local', index: '1' }) }

      it 'enqueues a plain (non-pollable) upload job and returns the delayed job' do
        expect(SecureRandom).to receive(:alphanumeric).with(10).and_return('S8baxMJnPl')

        returned_job = nil
        expect do
          returned_job = package_upload.upload_async_without_event(message:, package:, config:)
        end.to change(Delayed::Job, :count).by(1)

        job = Delayed::Job.last
        expect(returned_job).to eq(job)
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(package.guid)
        expect(job.handler).to include('/tmp/path-S8baxMJnPl')
        expect(job.handler).to include('PackageBits')
      end

      it 'does not create a pollable job (v2 JobPresenter needs a Delayed::Job)' do
        expect do
          package_upload.upload_async_without_event(message:, package:, config:)
        end.not_to change(PollableJobModel, :count)
      end

      it 'does not create an audit event' do
        expect(Repositories::PackageEventRepository).not_to receive(:record_app_package_upload)
        package_upload.upload_async_without_event(message:, package:, config:)
      end
    end

    describe '#upload_sync_without_event' do
      let(:package) { create(:package_model, type: 'bits') }
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }

      before do
        allow_any_instance_of(Jobs::V3::PackageBits).to receive(:perform).and_return(nil)
      end

      it 'performs the upload job' do
        expect_any_instance_of(Jobs::V3::PackageBits).to receive(:perform)
        package_upload.upload_sync_without_event(message, package)
      end

      context 'when the package is invalid' do
        before do
          allow_any_instance_of(Jobs::V3::PackageBits).to receive(:perform).and_raise(Sequel::ValidationFailed.new('message'))
        end

        it 'raises InvalidPackage' do
          expect do
            package_upload.upload_sync_without_event(message, package)
          end.to raise_error(PackageUpload::InvalidPackage)
        end
      end
    end
  end
end
