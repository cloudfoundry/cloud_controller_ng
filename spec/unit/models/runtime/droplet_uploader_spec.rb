require 'spec_helper'
require 'tmpdir'

describe CloudController::DropletUploader do
  let(:app) do
    VCAP::CloudController::AppFactory.make(droplet_hash: nil)
  end

  let(:blobstore) do
    CloudController::DependencyLocator.instance.droplet_blobstore
  end

  subject { described_class.new(app, blobstore) }

  describe '#upload' do
    include TempFileCreator

    context 'when the upload to the blobstore suceeds' do
      it 'adds a new app droplet' do
        expect(app.droplet_hash).to be_nil

        expect {
          subject.upload(temp_file_with_content.path)
        }.to change { app.droplets.size }.from(0).to(1)

        expect(app.droplet_hash).to eq(app.droplets.last.droplet_hash)
      end

      it 'deletes old droplets when there are more droplets than droplets_to_keep' do
        droplets_to_keep = 1
        expect(app.droplets.size).to eq(0)

        subject.upload(temp_file_with_content('droplet version 1').path, droplets_to_keep)
        expect(app.reload.droplets.size).to eq(droplets_to_keep)

        droplet_dest = Tempfile.new('downloaded_droplet')
        app.current_droplet.download_to(droplet_dest.path)
        expect(droplet_dest.read).to eql('droplet version 1')

        subject.upload(temp_file_with_content('droplet version 2').path, droplets_to_keep)
        expect(app.reload.droplets.size).to eq(droplets_to_keep)

        droplet_dest = Tempfile.new('downloaded_droplet')
        app.current_droplet.download_to(droplet_dest.path)
        expect(droplet_dest.read).to eql('droplet version 2')
      end
    end

    context 'when the upload to the blobstore fails' do
      before do
        allow(blobstore).to receive(:cp_to_blobstore).and_raise 'Upload failed'
      end

      it 'does not create a new droplet' do
        expect {
          expect {
            subject.upload(temp_file_with_content.path)
          }.to raise_error('Upload failed')
        }.not_to change {
          app.reload.droplets.size
        }
      end
    end
  end
end
