require "spec_helper"
require "cloud_controller/diego/docker/protocol"

module VCAP::CloudController
  module Diego
    module Common
      describe Protocol do
        subject(:protocol) { described_class.new }

        describe "#stop_index_request" do
          let(:app) { double(:app, :versioned_guid => "versioned-guid") }

          it "includes a subject and message for CfMessageBus::MessageBus#publish" do
            request = protocol.stop_index_request(app, 33)
            
            expect(request.size).to eq(2)
            expect(request.first).to eq("diego.stop.index")
            expect(request.last).to match_json({"process_guid" => "versioned-guid", "index" => 33})
          end
        end
      end
    end
  end
end
