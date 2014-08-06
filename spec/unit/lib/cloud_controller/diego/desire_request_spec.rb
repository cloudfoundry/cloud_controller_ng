require "spec_helper"

module VCAP::CloudController
  module Diego
    describe DesireRequest do
      let(:app) do
        instance_double(App,
          detected_start_command: "fake-detected_start_command",
          desired_instances: 111,
          disk_quota: 222,
          file_descriptors: 333,
          guid: "fake-guid",
          health_check_timeout: 444,
          memory: 555,
          stack: instance_double(Stack, name: "fake-stack"),
          versioned_guid: "fake-versioned_guid",
          uris: ["fake-uris"],
        )
      end

      let(:blobstore_url_generator) do
        double("blobstore_url_generator",
          :perma_droplet_download_url => "fake-droplet_uri",
        )
      end

      subject(:desire_request) do
        DesireRequest.new(app, blobstore_url_generator)
      end

      before do
        allow(Environment).to receive(:new).with(app).and_return([{name: "fake", value: "environment"}])
      end

      it "returns the correct DesireAppMessage for an application" do
        expect(desire_request.message.extract).to eq(
          disk_mb: 222,
          droplet_uri: "fake-droplet_uri",
          environment: [{name: "fake", value: "environment"}],
          file_descriptors: 333,
          health_check_timeout_in_seconds: 444,
          log_guid: "fake-guid",
          memory_mb: 555,
          num_instances: 111,
          process_guid: "fake-versioned_guid",
          stack: "fake-stack",
          start_command: "fake-detected_start_command",
          routes: ["fake-uris"],
        )
      end

      context "when the app does not have a health_check_timeout set" do
        before do
          allow(app).to receive(:health_check_timeout).and_return(nil)
        end

        it "omits health_check_timeout_in_seconds" do
          expect(desire_request.message.extract).not_to have_key(:health_check_timeout_in_seconds)
        end
      end
    end
  end
end
