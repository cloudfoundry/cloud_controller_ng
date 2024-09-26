require 'spec_helper'
require 'actions/package_delete'

module VCAP::CloudController
  RSpec.describe PackageDelete do
    subject(:package_delete) { PackageDelete.new(user_audit_info) }
    let(:user_guid) { 'schmuid' }
    let(:user_email) { 'amandaplease@gmail.com' }
    let(:user_audit_info) { UserAuditInfo.new(user_email:, user_guid:) }

    describe '#delete' do
      context 'when the package exists' do
        let!(:package) { PackageModel.make }

        it 'deletes the package record' do
          expect do
            package_delete.delete(package)
          end.to change(PackageModel, :count).by(-1)
          expect { package.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'schedules a job to the delete the blobstore item' do
          expect do
            package_delete.delete(package)
          end.to change(Delayed::Job, :count).by(1)

          job = Delayed::Job.last
          expect(job.handler).to include('VCAP::CloudController::Jobs::Runtime::BlobstoreDelete')
          expect(job.handler).to match(/key: ['"]?#{package.guid}/)
          expect(job.handler).to include('package_blobstore')
          expect(job.queue).to eq(Jobs::Queues.generic)
          expect(job.guid).not_to be_nil
        end

        it 'creates an v3 audit event' do
          expect(Repositories::PackageEventRepository).to receive(:record_app_package_delete).with(
            instance_of(PackageModel),
            user_audit_info
          )

          package_delete.delete(package)
        end

        it 'returns an empty error list' do
          expect(package_delete.delete(package)).to be_empty
        end

        it 'deletes associated labels' do
          label = PackageLabelModel.make(resource_guid: package.guid, key_name: 'test', value: 'bommel')
          expect do
            package_delete.delete([package])
          end.to change(PackageLabelModel, :count).by(-1)
          expect(label).not_to exist
          expect(package).not_to exist
        end

        it 'deletes associated annotations' do
          annotation = PackageAnnotationModel.make(resource_guid: package.guid, key_name: 'test', value: 'bommel')
          expect do
            package_delete.delete([package])
          end.to change(PackageAnnotationModel, :count).by(-1)
          expect(annotation).not_to exist
          expect(package).not_to exist
        end
      end

      context 'when passed a set of packages' do
        let!(:packages) { [PackageModel.make, PackageModel.make] }

        it 'bulk deletes them' do
          expect do
            package_delete.delete(packages)
          end.to change(PackageModel, :count).by(-2)
        end
      end
    end
  end
end
