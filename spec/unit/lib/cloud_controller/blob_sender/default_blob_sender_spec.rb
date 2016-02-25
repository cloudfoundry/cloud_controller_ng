require 'spec_helper'
require 'cloud_controller/blob_sender/default_blob_sender'

module CloudController
  module BlobSender
    describe DefaultLocalBlobSender do
      subject(:sender) do
        DefaultLocalBlobSender.new
      end

      let(:controller) { double('controller') }
      let(:blob) { double('blob', local_path: 'path/to/blob') }

      before do
        allow(controller).to receive(:send_file)
      end

      describe '#send_blob' do
        it 'sends the blob with local path' do
          expect(controller).to receive(:send_file).with(blob.local_path)
          sender.send_blob(blob, controller)
        end
      end
    end
  end
end
