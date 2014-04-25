require "spec_helper"
require "cloud_controller/blob_sender/default_blob_sender"

module CloudController
  module BlobSender
    describe NginxLocalBlobSender do
      let(:handler) { double("handler") }

      subject(:sender) do
        NginxLocalBlobSender.new(handler)
      end

      let(:controller) { double("controller") }
      let(:blob) { double("blob", download_url: "http://url/to/blob") }

      before do
        allow(controller).to receive(:send_file)
      end

      describe "#send_blob" do
        it "returns the correct status and headers" do
          expect(sender.send_blob("app_guid", "a blob", blob, controller)).to eql([200, {"X-Accel-Redirect" => "http://url/to/blob"}, ""])
        end

        it "calls handler when the path of the blob does not exist" do
          allow(blob).to receive(:download_url).and_return(nil)
          expect(handler).to receive(:handle_missing_blob!).with("app_guid", "a blob")
          sender.send_blob("app_guid", "a blob", blob, controller)
        end
      end
    end
  end
end