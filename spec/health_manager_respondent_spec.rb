# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "cloud_controller/health_manager_respondent"

module VCAP::CloudController
  describe HealthManagerRespondent do
    before :each do
      # save refreshes the timestamp
      @app = Models::App.make(
        :instances => 2,
      ).save
      @mbus = double("mock nats")
      @dea_client = double("mock dea client", :message_bus => @mbus)

      @mbus.should_receive(:subscribe).with(
        "cloudcontrollers.hm.requests.ng",
        :queue => "cc",
      )

      @respondent = HealthManagerRespondent.new(
        config.merge(
          :message_bus => @mbus,
          :dea_client => @dea_client,
        )
      )
    end

    describe "#process_hm_request" do
      describe "on START request" do
        it "should drop request if timestamps mismatch" do
          payload = {
            :droplet        => @app.guid,
            :op             => "START",
            :last_updated   => Time.now - 86400,
            :version        => @app.version,
            :indices        => [0,1],
          }

          @dea_client.should_not_receive(:start_instances_with_message)
          @mbus.should_not_receive(:publish).with(/^dea.+.start$/, anything)
          @respondent.process_hm_request(payload)
        end

        it "should drop request if versions mismatch" do
          payload = {
            :droplet        => @app.guid,
            :op             => "START",
            :last_updated   => @app.updated_at,
            :version        => 'deadbeaf-0',
            :indices        => [0,1],
          }

          @dea_client.should_not_receive(:start_instances_with_message)
          @mbus.should_not_receive(:publish).with(/^dea.+.start$/, anything)
          @respondent.process_hm_request(payload)
        end

        it "should drop request if app isn't started" do
          payload = {
            :droplet        => @app.guid,
            :op             => "START",
            :last_updated   => @app.updated_at,
            :version        => @app.version,
            :indices        => [0,1],
          }
          @dea_client.should_not_receive(:start_instances_with_message)
          @mbus.should_not_receive(:publish).with(/^dea.+.start$/, anything)
          @respondent.process_hm_request(payload)
        end

        it "should send a start request to dea" do
          @app.update(
            :state => "STARTED",
            :package_hash => "abc",
            :package_state => "STAGED",
          )

          payload = {
            :droplet        => @app.guid,
            :op             => "START",
            :last_updated   => @app.updated_at,
            :version        => @app.version,
            :indices        => [1],
          }
          @dea_client.should_receive(:start_instances_with_message).with(
            # XXX: we should do something about this, like overriding
            # Sequel::Model#eql? or something that ignores the nanosecond
            # nonsense
            respond_with(:guid => @app.guid),
            [1],
            {},
          )

          @respondent.process_hm_request(payload)
        end

        it "should send a start request indicating a flapping app" do
          @app.update(
            :state => "STARTED",
            :package_hash => "abc",
            :package_state => "STAGED",
          )

          payload = {
            :droplet        => @app.guid,
            :op             => "START",
            :last_updated   => @app.updated_at,
            :version        => @app.version,
            :indices        => [1],
            :flapping       => true,
          }
          @dea_client.should_receive(:start_instances_with_message).with(
            respond_with(:guid => @app.guid),
            [1],
            :flapping => true,
          )

          @respondent.process_hm_request(payload)
        end
      end

      describe "on STOP request" do
        it "should drop request if timestamps mismatch" do
          payload = {
            :droplet        => @app.guid,
            :op             => "STOP",
            :last_updated   => Time.now - 86400,
            :instances      => [0,1],
          }

          @dea_client.should_not_receive(:stop_instances)
          @mbus.should_not_receive(:publish).with(/^dea.+.start$/, anything)
          @respondent.process_hm_request(payload)
        end

        it "should send a stop request to dea for a runaway app" do
          @app.destroy

          payload = {
            :droplet        => @app.guid,
            :op             => "STOP",
            :last_updated   => @app.updated_at,
            :instances        => [1],
          }
          @dea_client.should_receive(:stop) do |app|
            app.guid.should == @app.guid
          end

          @respondent.process_hm_request(payload)
        end

        it "should send a stop request to dea" do
          payload = {
            :droplet        => @app.guid,
            :op             => "STOP",
            :last_updated   => @app.updated_at,
            :instances        => [1],
          }

          @dea_client.should_receive(:stop_instances).with(
            respond_with(:guid => @app.guid),
            [1],
          )

          @respondent.process_hm_request(payload)
        end
      end

      describe "on SPINDOWN request" do
        it "should drop the request if app already stopped" do
          @app.update(
            :state => "STOPPED",
          )

          payload = {
            :droplet        => @app.guid,
            :op             => "SPINDOWN",
          }
          @dea_client.should_not_receive(:stop)
          @mbus.should_not_receive(:publish).with(
            "dea.stop",
            anything,
          )

          @respondent.process_hm_request(payload)
        end

        it "should stop an app" do
          @app.update(
            :state => "STARTED",
            :package_hash => "abc",
            :package_state => "STAGED",
          )

          payload = {
            :droplet        => @app.guid,
            :op             => "SPINDOWN",
          }
          @dea_client.should_receive(:stop).with(
            respond_with(:guid => @app.guid),
          )
          @respondent.process_hm_request(payload)
        end

        it "should update the state of an app to stopped" do
          @app.update(
            :state => "STARTED",
            :package_hash => "abc",
            :package_state => "STAGED",
          )
          payload = {
            :droplet        => @app.guid,
            :op             => "SPINDOWN",
          }

          @dea_client.should_receive(:stop)
          @respondent.process_hm_request(payload)

          @app.reload.should be_stopped
        end
      end
    end
  end
end
