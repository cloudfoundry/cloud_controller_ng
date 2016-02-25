require 'spec_helper'
require 'cloud_controller/blob_sender/default_blob_sender'

module CloudController
  module BlobSender
    describe NginxLocalBlobSender do
      subject(:sender) do
        NginxLocalBlobSender.new
      end

      let(:controller) { double('controller') }
      let(:blob) { instance_double(Blobstore::FogBlob, internal_download_url: 'http://url/to/blob') }

      before do
        allow(controller).to receive(:send_file)
      end

      describe '#send_blob' do
        it 'returns the correct status and headers' do
          expect(sender.send_blob(blob, controller)).to eql([200, { 'X-Accel-Redirect' => 'http://url/to/blob' }, ''])
        end
      end
    end
  end
end
