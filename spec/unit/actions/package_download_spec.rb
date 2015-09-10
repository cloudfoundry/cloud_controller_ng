require 'spec_helper'
require 'actions/package_download'

module VCAP::CloudController
  describe PackageDownload do
    subject(:package_download) { PackageDownload.new }

    describe '#download' do
      let(:package) { PackageModel.make(
        state: 'READY',
        type: 'BITS',
      )
      }
      let(:download_location) { 'http://package.download.url' }
      let(:blob_double) { instance_double(CloudController::Blobstore::Blob) }

      before do
        allow_any_instance_of(CloudController::Blobstore::Client).to receive(:blob).and_return(blob_double)
      end

      context 'the storage is S3' do
        before do
          allow_any_instance_of(CloudController::Blobstore::Client).to receive(:local?).and_return(false)
          allow(blob_double).to receive(:download_url).and_return(download_location)
        end

        it 'fetches and returns the download URL' do
          file, url = package_download.download(package)
          expect(url).to eq(download_location)
          expect(file).to be_nil
        end
      end

      context 'the storage is NFS' do
        before do
          allow_any_instance_of(CloudController::Blobstore::Client).to receive(:local?).and_return(true)
          allow(blob_double).to receive(:local_path).and_return(download_location)
        end

        it 'reports the file path' do
          file, url = package_download.download(package)
          expect(file).to eq(download_location)
          expect(url).to be_nil
        end
      end
    end
  end
end
