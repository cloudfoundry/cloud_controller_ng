require 'spec_helper'
require 'actions/package_copy'

module VCAP::CloudController
  RSpec.describe PackageCopy do
    let(:package_copy) { PackageCopy.new(user_guid, user_email) }
    let(:user_guid) { 'gooid' }
    let(:user_email) { 'amelia@cats.com' }

    describe '#copy' do
      let(:target_app) { AppModel.make }
      let!(:source_package) { PackageModel.make(type: type) }
      let(:type) { 'docker' }
      let(:app_guid) { target_app.guid }

      before do
        allow(Repositories::PackageEventRepository).to receive(:record_app_package_copy)
      end

      it 'creates the package with the correct values' do
        result = package_copy.copy(app_guid, source_package)

        expect(target_app.packages.first).to eq(result)
        created_package = PackageModel.find(guid: result.guid)
        expect(created_package).to eq(result)
        expect(created_package.type).to eq(type)
      end

      it 'copies over docker info' do
        PackageDockerDataModel.create(package: source_package, image: 'image-magick.com')
        result = package_copy.copy(app_guid, source_package)
        created_package = PackageModel.find(guid: result.guid)

        expect(created_package.docker_data.image).to eq('image-magick.com')
      end

      it 'creates an v3 audit event' do
        expect(Repositories::PackageEventRepository).to receive(:record_app_package_copy).with(
          instance_of(PackageModel),
          user_guid,
          user_email,
          source_package.guid
        )

        package_copy.copy(app_guid, source_package)
      end

      describe 'package state' do
        context 'when type is bits' do
          let(:type) { 'bits' }

          it 'sets the state to COPYING_STATE' do
            result = package_copy.copy(app_guid, source_package)
            expect(result.type).to eq('bits')
            expect(result.state).to eq(PackageModel::COPYING_STATE)
          end

          it 'enqueues a job to copy the bits in the blobstore' do
            package = nil
            expect {
              package = package_copy.copy(app_guid, source_package)
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
            result = package_copy.copy(app_guid, source_package)
            expect(result.type).to eq('docker')
            expect(result.state).to eq(PackageModel::READY_STATE)
          end

          it 'does no enqueue a job to copy the bits in the blobstore' do
            expect {
              package_copy.copy(app_guid, source_package)
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
            package_copy.copy(app_guid, source_package)
          }.to raise_error(PackageCopy::InvalidPackage, 'the message')
        end
      end

      context 'when the source and destination apps are the same' do
        let!(:source_package) { PackageModel.make(type: type, app_guid: target_app.guid) }

        it 'raises an InvalidPackage error' do
          expect {
            package_copy.copy(app_guid, source_package)
          }.to raise_error(PackageCopy::InvalidPackage, 'Source and destination app cannot be the same')
        end
      end
    end
  end
end
