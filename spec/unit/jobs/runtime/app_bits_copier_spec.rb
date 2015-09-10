require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    describe AppBitsCopier do
      let(:src_app) { VCAP::CloudController::AppFactory.make }
      let(:dest_app) { VCAP::CloudController::AppFactory.make }
      let(:compressed_path) { File.expand_path('../../../fixtures/good.zip', File.dirname(__FILE__)) }
      let(:local_tmp_dir) { Dir.mktmpdir }
      let(:blobstore_dir) { Dir.mktmpdir }
      let(:app_event_repository) { double(:app_event_repository, record_src_copy_bits: nil, record_dest_copy_bits: nil) }
      let(:package_blobstore) do
        CloudController::Blobstore::Client.new({ provider: 'Local', local_root: blobstore_dir }, 'package')
      end
      let(:user) { User.make }
      let(:email) { 'some-user@example.com' }

      subject(:job) do
        AppBitsCopier.new(src_app, dest_app, app_event_repository, user, email)
      end

      it { is_expected.to be_a_valid_job }

      before do
        Fog.unmock!
      end

      after do
        Fog.mock!
        FileUtils.remove_entry_secure local_tmp_dir
        FileUtils.remove_entry_secure blobstore_dir
      end

      describe '#perform' do
        before do
          package_blobstore.cp_to_blobstore(compressed_path, src_app.guid)
        end

        it 'creates blob stores' do
          expect(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          job.perform
        end

        it 'copies the source package zip to the package blob store for the destination app' do
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          job.perform
          expect(package_blobstore.exists?(dest_app.guid)).to be true
        end

        it 'uploads the package zip to the package blob store' do
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          job.perform
          package_blobstore.download_from_blobstore(dest_app.guid, File.join(local_tmp_dir, 'package.zip'))
          expect(`unzip -l #{local_tmp_dir}/package.zip`).to include('bye')
        end

        it 'changes the package hash in the destination app' do
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          expect {
            job.perform
          }.to change {
            dest_app.refresh.package_hash
          }
        end

        it 'creates a copy_bits audit event for source app' do
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          job.perform
          expect(app_event_repository).to have_received(:record_src_copy_bits).with(dest_app, src_app, user.guid, email)
        end

        it 'creates a copy_bits audit event for destination app' do
          allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore).and_return(package_blobstore)
          job.perform
          expect(app_event_repository).to have_received(:record_dest_copy_bits).with(dest_app, src_app, user.guid, email)
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:app_bits_copier)
        end
      end
    end
  end
end
