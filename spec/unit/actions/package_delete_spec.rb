require 'spec_helper'
require 'actions/package_delete'

module VCAP::CloudController
  RSpec.describe PackageDelete do
    subject(:package_delete) { PackageDelete.new(user_guid, user_email) }
    let(:user_guid) { 'schmuid' }
    let(:user_email) { 'amandaplease@gmail.com' }

    describe '#delete' do
      context 'when the package exists' do
        let!(:package) { PackageModel.make }

        it 'deletes the package record' do
          expect {
            package_delete.delete(package)
          }.to change { PackageModel.count }.by(-1)
          expect { package.refresh }.to raise_error Sequel::Error, 'Record not found'
        end

        it 'schedules a job to the delete the blobstore item' do
          expect {
            package_delete.delete(package)
          }.to change {
            Delayed::Job.count
          }.by(1)

          job = Delayed::Job.last
          expect(job.handler).to include('VCAP::CloudController::Jobs::Runtime::BlobstoreDelete')
          expect(job.handler).to include("key: #{package.guid}")
          expect(job.handler).to include('package_blobstore')
          expect(job.queue).to eq('cc-generic')
          expect(job.guid).not_to be_nil
        end

        it 'creates an v3 audit event' do
          expect(Repositories::PackageEventRepository).to receive(:record_app_package_delete).with(
            instance_of(PackageModel),
            user_guid,
            user_email
          )

          package_delete.delete(package)
        end
      end

      context 'when passed a set of packages' do
        let!(:packages) { [PackageModel.make, PackageModel.make] }

        it 'bulk deletes them' do
          expect {
            package_delete.delete(packages)
          }.to change {
            PackageModel.count
          }.by(-2)
        end
      end
    end
  end
end
