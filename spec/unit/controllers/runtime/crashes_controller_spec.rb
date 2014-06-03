require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::CrashesController, type: :controller do
    describe "GET /v2/apps/:id/crashes" do
      before :each do
        @app = AppFactory.make
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      context "as a developer" do
        it "should return the crashed instances" do
          crashed_instances = [
                               { :instance => "instance_1", :since => 1 },
                               { :instance => "instance_2", :since => 1 },
                              ]

          expected = [
                      { "instance" => "instance_1", "since" => 1 },
                      { "instance" => "instance_2", "since" => 1 },

                     ]

          health_manager_client = CloudController::DependencyLocator.instance.health_manager_client
          health_manager_client.should_receive(:find_crashes).with(@app).and_return(crashed_instances)

          get("/v2/apps/#{@app.guid}/crashes", {}, headers_for(@developer))

          last_response.status.should == 200
          Yajl::Parser.parse(last_response.body).should == expected
        end
      end

      context "as a user" do
        it "should return 403" do
          get("/v2/apps/#{@app.guid}/crashes",
              {},
              headers_for(@user))

              last_response.status.should == 403
        end
      end
    end
  end
end
