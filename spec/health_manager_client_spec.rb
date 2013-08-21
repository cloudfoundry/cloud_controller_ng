require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::HealthManagerClient do
    let(:app) { Models::App.make }
    let(:apps) { [Models::App.make, Models::App.make, Models::App.make] }
    #let(:message_bus) { Config.message_bus }
    let(:message_bus) { @health_manager_client.send(:message_bus) }

    before do
      @health_manager_client = CloudController::DependencyLocator.instance.health_manager_client
    end

    describe "find_status" do
      it "should use specified message options" do
        app.should_receive(:guid).and_return(1)
        app.should_receive(:instances).and_return(2)

        encoded = { :droplet => 1, :other_opt => "value" }
        message_bus.should_receive(:synchronous_request).
          with("healthmanager.status", encoded, {:result_count => 2, :timeout => 2}).and_return(["status"])

        @health_manager_client.find_status(app, { :other_opt => "value" }).should == "status"
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

          message_bus.should_receive(:synchronous_request).and_return([resp])
          @health_manager_client.healthy_instances(app).should == 3
        end
      end

      context "single app as an array" do
        it "should return num healthy instances as a hash" do
          resp = {
            :droplet => app.guid,
            :version => app.version,
            :healthy => 3
          }

          message_bus.should_receive(:synchronous_request).and_return([resp])
          @health_manager_client.healthy_instances([app]).should == {
            app.guid => 3
          }
        end
      end

      context "multiple apps" do
        it "should return num healthy instances for each app" do
          resp = apps.map do |app|
            {
              :droplet => app.guid,
              :version => app.version,
              :healthy => 3,
            }
          end

          message_bus.should_receive(:synchronous_request).and_return(resp)

          expected = {}
          apps.each { |app| expected[app.guid] = 3 }
          @health_manager_client.healthy_instances(apps).should == expected
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

        message_bus.should_receive(:synchronous_request).and_return([resp])
        @health_manager_client.find_crashes(app).should == resp[:instances]
      end
    end

    describe "notify_app_updated" do
      it "should publish droplet.updated" do
        message_bus.should_receive(:publish).with("droplet.updated", :droplet => app.guid, :cc_partition => "ng")
        @health_manager_client.notify_app_updated(app.guid)
      end
    end
  end
end
