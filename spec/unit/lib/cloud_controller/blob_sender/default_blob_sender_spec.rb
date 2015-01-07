require 'spec_helper'
require 'cloud_controller/blob_sender/default_blob_sender'

module CloudController
  module BlobSender
    describe DefaultLocalBlobSender do
      let(:handler) { double('handler') }

      subject(:sender) do
        DefaultLocalBlobSender.new(handler)
      end

      let(:controller) { double('controller') }
      let(:blob) { double('blob', local_path: 'path/to/blob') }

      before do
        allow(controller).to receive(:send_file)
      end

      describe '#send_blob' do
        it 'sends the blob with local path' do
          expect(controller).to receive(:send_file).with(blob.local_path)
          sender.send_blob('app_guid', 'a blob', blob, controller)
        end

        it 'calls handler when the path of the blob does not exist' do
          allow(blob).to receive(:local_path).and_return(nil)
          expect(handler).to receive(:handle_missing_blob!).with('app_guid', 'a blob')
          sender.send_blob('app_guid', 'a blob', blob, controller)
        end
      end
    end
  end
end
