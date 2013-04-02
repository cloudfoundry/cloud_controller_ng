# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Instances do
    describe "GET /v2/apps/:id/instances" do
      before :each do
        @app = Models::App.make(:package_hash => "abc", :package_state => "STAGED")
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      context "as a developer" do
        it "returns 400 when there is an error finding the instances" do
          instance_id = 5

          @app.state = "STOPPED"
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(@developer))

          last_response.status.should == 400
          Yajl::Parser.parse(last_response.body)["code"].should == 220001
        end

        it "returns '170002 NotStaged' when the app is failed to stage" do
          @app.package_state = "FAILED"
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(@developer))

          last_response.status.should == 400
          Yajl::Parser.parse(last_response.body)["code"].should == 170002
        end

        it "returns '170002 NotStaged' when the app is pending to be staged" do
          @app.package_state = "PENDING"
          @app.save

          get("/v2/apps/#{@app.guid}/instances", {}, headers_for(@developer))

          last_response.status.should == 400
          Yajl::Parser.parse(last_response.body)["code"].should == 170002
        end

        it "returns the instances" do
          @app.state = "STARTED"
          @app.instances = 1
          @app.save

          @app.refresh

          instances = {
            0 => {
              :state => "FLAPPING",
              :since => 1,
            },
            1 => {
              :state => "STARTING",
              :since => 2,
              :debug_ip => "1.2.3.4",
              :debug_port => 1001,
              :console_ip => "1.2.3.5",
              :console_port => 1002,
            },
            2 => {
              :state => "RUNNING",
              :since => 3,
              :debug_ip => "2.3.4.5",
              :debug_port => 2001,
              :console_ip => "2.3.4.6",
              :console_port => 2002,
            },
          }

          expected = {
            "0" => {
              "state" => "FLAPPING",
              "since" => 1,
            },
            "1" => {
              "state" => "STARTING",
              "since" => 2,
              "debug_ip" => "1.2.3.4",
              "debug_port" => 1001,
              "console_ip" => "1.2.3.5",
              "console_port" => 1002,
            },
            "2" => {
              "state" => "RUNNING",
              "since" => 3,
              "debug_ip" => "2.3.4.5",
              "debug_port" => 2001,
              "console_ip" => "2.3.4.6",
              "console_port" => 2002,
            },
          }

          DeaClient.should_receive(:find_all_instances).with(@app).
            and_return(instances)

          get("/v2/apps/#{@app.guid}/instances",
              {},
              headers_for(@developer))

              last_response.status.should == 200
              Yajl::Parser.parse(last_response.body).should == expected
        end
      end

      context "as a user" do
        it "should return 403" do
          get("/v2/apps/#{@app.guid}/instances",
              {},
              headers_for(@user))

              last_response.status.should == 403
        end
      end
    end
  end
end
