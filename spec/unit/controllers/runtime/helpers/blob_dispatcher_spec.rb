require 'spec_helper'

module VCAP::CloudController
  describe BlobDispatcher do
    subject(:dispatcher) { described_class.new(blob_sender: blob_sender, controller: controller) }

    let(:blob_sender) { instance_double(CloudController::BlobSender::DefaultLocalBlobSender, send_blob: nil) }
    let(:controller) { instance_double(RestController::BaseController) }

    describe '#send_or_redirect' do
      let(:blob) { instance_double(CloudController::Blobstore::FogBlob) }

      context 'when local is true' do
        let(:local) { true }

        it 'delegates to the blob sender' do
          dispatcher.send_or_redirect(local: local, blob: blob)

          expect(blob_sender).to have_received(:send_blob).with(blob, controller)
        end
      end

      context 'when local is false' do
        let(:local) { false }

        before do
          allow(blob).to receive(:public_download_url).and_return('some download url')
        end

        context 'when the controller is v2' do
          before do
            allow(controller).to receive(:redirect)
          end

          it 'redirects the controller to the public_download_url' do
            dispatcher.send_or_redirect(local: local, blob: blob)

            expect(controller).to have_received(:redirect).with('some download url')
          end
        end

        context 'when the controller is v3' do
          let(:controller) { ApplicationController.new }

          before do
            allow(controller).to receive(:redirect_to)
          end

          it 'redirects the controller to the public_download_url' do
            dispatcher.send_or_redirect(local: local, blob: blob)
            expect(controller).to have_received(:redirect_to).with('some download url')
          end
        end

        context 'when SigningRequestError is raisesd' do
          before do
            allow(blob).to receive(:public_download_url).and_raise(CloudController::Blobstore::SigningRequestError.new)
          end

          it 'raises a BlobstoreUnavailble ApiError' do
            expect {
              dispatcher.send_or_redirect(local: local, blob: blob)
            }.to raise_error do |e|
              expect(e).to be_a(VCAP::Errors::ApiError)
              expect(e.name).to eq('BlobstoreUnavailable')
            end
          end
        end
      end
    end
  end
end
