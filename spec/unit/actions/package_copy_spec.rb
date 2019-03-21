require 'spec_helper'
require 'actions/package_copy'

module VCAP::CloudController
  RSpec.describe PackageCopy do
    subject(:package_copy) { PackageCopy.new }

    let(:target_app) { AppModel.make }
    let!(:source_package) { PackageModel.make(type: type) }
    let(:type) { 'docker' }

    describe '#copy' do
      let(:user_guid) { 'gooid' }
      let(:user_email) { 'amelia@cats.com' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }

      before do
        allow(Repositories::PackageEventRepository).to receive(:record_app_package_copy)
      end

      it 'creates the package with the correct values' do
        result = package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)

        expect(target_app.packages.first).to eq(result)
        created_package = PackageModel.find(guid: result.guid)
        expect(created_package).to eq(result)
        expect(created_package.type).to eq(type)
      end

      it 'copies over docker info' do
        source_package = PackageModel.make(type: 'docker', docker_image: 'image-magick.com')
        result = package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
        created_package = PackageModel.find(guid: result.guid)

        expect(created_package.image).to eq('image-magick.com')
      end

      it 'creates an audit event' do
        expect(Repositories::PackageEventRepository).to receive(:record_app_package_copy).with(
          instance_of(PackageModel),
          user_audit_info,
          source_package.guid
        )

        package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
      end

      describe 'package state' do
        context 'when type is bits' do
          let(:type) { 'bits' }

          it 'sets the state to COPYING_STATE' do
            result = package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
            expect(result.type).to eq('bits')
            expect(result.state).to eq(PackageModel::COPYING_STATE)
          end

          it 'enqueues a job to copy the bits in the blobstore' do
            package = nil
            expect {
              package = package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
            }.to change { Delayed::Job.count }.by(1)

            job = Delayed::Job.last
            expect(job.queue).to eq('cc-generic')
            expect(job.handler).to include(package.guid)
            expect(job.handler).to include(source_package.guid)
            expect(job.handler).to include('PackageBitsCopier')
          end
        end

        context 'when the type is docker' do
          it 'sets the state to READY_STATE' do
            result = package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
            expect(result.type).to eq('docker')
            expect(result.state).to eq(PackageModel::READY_STATE)
          end

          it 'does no enqueue a job to copy the bits in the blobstore' do
            expect {
              package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
            }.not_to change { Delayed::Job.count }
          end
        end
      end

      context 'when model validation fails' do
        before do
          allow_any_instance_of(PackageModel).to receive(:save).and_raise(Sequel::ValidationFailed.new('the message'))
        end

        it 'raises an InvalidPackage error' do
          expect {
            package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
          }.to raise_error(PackageCopy::InvalidPackage, 'the message')
        end
      end

      context 'when the source and destination apps are the same' do
        let!(:source_package) { PackageModel.make(type: type, app_guid: target_app.guid) }

        it 'raises an InvalidPackage error' do
          expect {
            package_copy.copy(destination_app_guid: target_app.guid, source_package: source_package, user_audit_info: user_audit_info)
          }.to raise_error(PackageCopy::InvalidPackage, 'Source and destination app cannot be the same')
        end
      end
    end

    describe '#copy_without_event' do
      it 'creates the package with the correct values' do
        result = package_copy.copy_without_event(target_app.guid, source_package)

        expect(target_app.packages.first).to eq(result)
        created_package = PackageModel.find(guid: result.guid)
        expect(created_package).to eq(result)
        expect(created_package.type).to eq(type)
      end

      it 'does not create an audit event' do
        expect(Repositories::PackageEventRepository).not_to receive(:record_app_package_copy)
        package_copy.copy_without_event(target_app.guid, source_package)
      end
    end
  end
end
