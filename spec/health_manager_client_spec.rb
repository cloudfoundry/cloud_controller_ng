# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::HealthManagerClient do
    let(:app) { Models::App.make }
    let(:apps) { [Models::App.make, Models::App.make, Models::App.make] }
    let(:message_bus) { double(:message_bus) }

    before do
      HealthManagerClient.configure(message_bus)
    end

    describe "find_status" do
      it "should use specified message options" do
        app.should_receive(:guid).and_return(1)
        app.should_receive(:instances).and_return(2)

        status_json = "\"status\""
        encoded = Yajl::Encoder.encode({"droplet" => 1, "other_opt" => "value"})
        message_bus.should_receive(:request).
          with("healthmanager.status", encoded, {:expected => 2, :timeout => 2}).
          and_return([status_json])

        HealthManagerClient.find_status(app, { :other_opt => "value" }).
          should == "status"
      end
    end

    describe "healthy_instances" do
      context "single app" do
        it "should return num healthy instances" do
          resp = {
            :droplet => app.guid,
            :version => app.version,
            :healthy => 3
          }
          resp_json = Yajl::Encoder.encode(resp)

          message_bus.should_receive(:request).and_return([resp_json])
          HealthManagerClient.healthy_instances(app).should == 3
        end
      end

      context "multiple apps" do
        it "should return num healthy instances for each app" do
          resp = apps.map do |app|
            Yajl::Encoder.encode({
                                   :droplet => app.guid,
                                   :version => app.version,
                                   :healthy => 3,
                                 })
          end

          message_bus.should_receive(:request).and_return(resp)

          expected = {}
          apps.each { |app| expected[app.guid] = 3 }
          HealthManagerClient.healthy_instances(apps).should == expected
        end
      end
    end

    describe "find_crashes" do
      it "should return crashed instances" do
        resp = {
          :instances => [
                         { :instance => "instance_1", :since => 1 },
                         { :instance => "instance_2", :since => 1 },
                        ]
        }
        resp_json = Yajl::Encoder.encode(resp)

        message_bus.should_receive(:request).and_return([resp_json])
        HealthManagerClient.find_crashes(app).should == resp[:instances]
      end
    end
  end
end
