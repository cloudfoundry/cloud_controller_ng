require 'spec_helper'

module CloudController
  module BlobSender
    describe NginxLocalBlobSender do
      subject(:sender) do
        described_class.new
      end

      let(:blob) { instance_double(Blobstore::FogBlob, internal_download_url: 'http://url/to/blob') }

      describe '#send_blob' do
        context 'when the controller is a v2 controller' do
          let(:controller) { instance_double(VCAP::CloudController::RestController::BaseController) }

          it 'returns the correct status and headers' do
            expect(sender.send_blob(blob, controller)).to eql([200, { 'X-Accel-Redirect' => 'http://url/to/blob' }, ''])
          end
        end

        context 'when the controller is a v3 controller' do
          let(:controller) { ApplicationController.new }

          before do
            controller.instance_variable_set(:@_response, Rack::Response.new)
          end

          it 'returns the correct status and headers' do
            sender.send_blob(blob, controller)

            expect(controller.response_body).to be_nil
            expect(controller.status).to eq(200)
            expect(controller.response.headers).to include('X-Accel-Redirect' => 'http://url/to/blob')
          end
        end
      end
    end
  end
end
