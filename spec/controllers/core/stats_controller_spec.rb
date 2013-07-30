require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::StatsController, type: :controller do
    describe "GET /v2/apps/:id/stats" do
      before :each do
        @app = Models::App.make(:package_hash => "abc", :package_state => "STAGED")
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
        @auditor = make_auditor_for_space(@app.space)
      end

      context "as a developer" do
        it "should return 400 when there is an error finding the instances" do
          instance_id = 5

          @app.state = "STOPPED"
          @app.save

          get("/v2/apps/#{@app.guid}/stats",
              {},
              headers_for(@developer))

              last_response.status.should == 400
        end

        it "should return the stats" do
          @app.state = "STARTED"
          @app.instances = 1
          @app.save

          @app.refresh

          stats = {
            0 => {
              :state => "RUNNING",
              :stats => "mock stats",
            },
            1 => {
              :state => "DOWN",
              :since => 1,
            }
          }

          expected = {
            "0" => {
              "state" => "RUNNING",
              "stats" => "mock stats",
            },
            "1" => {
              "state" => "DOWN",
              "since" => 1,
            }
          }

          DeaClient.should_receive(:find_stats).with(@app, {}).
            and_return(stats)

          get("/v2/apps/#{@app.guid}/stats",
              {},
              headers_for(@developer))

          last_response.status.should == 200
          Yajl::Parser.parse(last_response.body).should == expected
        end
      end

      context "as a user" do
        it "should return 403" do
          get("/v2/apps/#{@app.guid}/stats",
              {},
              headers_for(@user))

              last_response.status.should == 403
        end
      end

      context "as an auditor" do

        it "should return the stats" do
          @app.state = "STARTED"
          @app.instances = 1
          @app.save

          @app.refresh

          stats = {
            0 => {
              :state => "RUNNING",
              :stats => "mock stats",
            },
            1 => {
              :state => "DOWN",
              :since => 1,
            }
          }

          expected = {
            "0" => {
              "state" => "RUNNING",
              "stats" => "mock stats",
            },
            "1" => {
              "state" => "DOWN",
              "since" => 1,
            }
          }

          DeaClient.should_receive(:find_stats).with(@app, {}).
            and_return(stats)

          get("/v2/apps/#{@app.guid}/stats",
              {},
              headers_for(@auditor))

          last_response.status.should == 200
          Yajl::Parser.parse(last_response.body).should == expected
        end
      end
    end
  end
end
