require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BlobDispatcher do
    subject(:dispatcher) { described_class.new(blobstore: blobstore, controller: controller) }

    let(:blob_sender) { instance_double(CloudController::BlobSender::DefaultLocalBlobSender, send_blob: nil) }
    let(:blobstore) { double(local?: local) }
    let(:controller) { instance_double(RestController::BaseController) }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:blob_sender) { blob_sender }
      allow(CloudController::DependencyLocator.instance).to receive(:package_blobstore) { package_blobstore }
    end

    describe '#send_or_redirect' do
      let(:blob) { instance_double(CloudController::Blobstore::FogBlob) }
      let(:package_guid) { 'package-guid' }

      before do
        allow(blobstore).to receive(:blob).with(package_guid) { blob }
      end

      context 'when the blob does not exist' do
        let(:local) { true }
        let(:blob) { nil }

        it 'raises BlobNotFound' do
          expect {
            dispatcher.send_or_redirect(guid: package_guid)
          }.to raise_error(CloudController::Errors::BlobNotFound)
        end
      end

      context 'when local is true' do
        let(:local) { true }

        it 'delegates to the blob sender' do
          dispatcher.send_or_redirect(guid: package_guid)

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
            dispatcher.send_or_redirect(guid: package_guid)

            expect(controller).to have_received(:redirect).with('some download url')
          end
        end

        context 'when the controller is v3' do
          let(:controller) { ApplicationController.new }

          before do
            allow(controller).to receive(:redirect_to)
          end

          it 'redirects the controller to the public_download_url' do
            dispatcher.send_or_redirect(guid: package_guid)
            expect(controller).to have_received(:redirect_to).with('some download url')
          end
        end

        context 'when SigningRequestError is raisesd' do
          before do
            allow(blob).to receive(:public_download_url).and_raise(CloudController::Blobstore::SigningRequestError.new)
          end

          it 'raises a BlobstoreUnavailble ApiError' do
            expect {
              dispatcher.send_or_redirect(guid: package_guid)
            }.to raise_error do |e|
              expect(e).to be_a(CloudController::Errors::ApiError)
              expect(e.name).to eq('BlobstoreUnavailable')
            end
          end
        end
      end
    end
  end
end
