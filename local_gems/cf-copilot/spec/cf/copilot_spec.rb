RSpec.describe Cloudfoundry::Copilot do
  before(:all) do
    @copilotServer = fork do
      exec "cd spec/cf/fixtures && exec copilot-server -config copilot-config.json"
    end

    Process.detach(@copilotServer)
    @client = Cloudfoundry::Copilot::Client.new(
        host: "127.0.0.1",
        port: 5002,
        client_ca: File.open('spec/cf/fixtures/fakeCA.crt').read,
        client_key: File.open('spec/cf/fixtures/cloud-controller-client.key').read,
        client_chain: File.open('spec/cf/fixtures/cloud-controller-client.crt').read
    )
    healthy = false
    num_tries = 0
    until healthy
      begin
        healthy = @client.health
      rescue
        sleep 1
        num_tries += 1
        if num_tries > 5
          fail "copilot didn't become healthy"
        end
      end
    end
  end

  after(:all) do
    Process.kill("TERM", @copilotServer)
  end

  it "can upsert a route" do
    @client.upsert_route(
                     guid: "some-route-guid",
                     host: "some-route-url"
    )
  end

  it "can delete a route" do
    @client.delete_route(
        guid: "some-route-guid"
    )
  end

  it "can map a route" do
    @client.map_route(
        capi_process_guid: "some-capi-process-guid",
        diego_process_guid: "some-diego-process-guid",
        route_guid: "some-route-guid"
    )
  end

  it "can unmap a route" do
    @client.unmap_route(
        capi_process_guid: "some-capi-process-guid",
        route_guid: "some-route-guid"
    )
  end
end
