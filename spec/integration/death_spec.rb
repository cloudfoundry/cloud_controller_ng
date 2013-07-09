require "spec_helper"

describe "Cloud controller", :type => :integration do
  before(:all) do
    start_nats
    start_cc
  end

  after(:all) do
    stop_cc
    stop_nats
  end

  context "upon shutdown" do
    it "unregisters its route" do
      received = nil

      thd = Thread.new do
        NATS.start do
          sid = NATS.subscribe("router.unregister") do |msg|
            received = msg
            NATS.stop
          end

          NATS.timeout(sid, 15) do
            fail "never got anything over NATS"
          end
        end
      end

      stop_cc

      thd.join

      expected = {
        "host" => "127.0.0.1",
        "port" => 8181,
        "tags" => {"component" => "CloudController"},
        "uris" => ["api2.vcap.me"]
      }

      received.should json_match(expected)
    end
  end
end
