require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::RestagingController, type: :controller do
    describe "POST /v2/apps/:id/restage" do
      before :each do
        @app = AppFactory.make(:package_hash => "abc", :package_state => "STAGED")
        @user =  make_user_for_space(@app.space)
        @developer = make_developer_for_space(@app.space)
      end

      context "as a developer" do
        subject { post("/v2/apps/#{@app.guid}/restage", {}, headers_for(@developer)) }

        it "returns '170002 NotStaged' when the app is pending to be staged" do
          @app.package_state = "PENDING"
          @app.save

          subject

          last_response.status.should == 400
          Yajl::Parser.parse(last_response.body)["code"].should == 170002
        end

        it "returns 200 and marks app as pending for restage" do
          expect(@app.refresh).not_to be_pending

          subject

          expect(@app.refresh).to be_pending
          last_response.status.should == 200
        end
      end

      context "as a user" do
        it "should return 403" do
          post("/v2/apps/#{@app.guid}/restage",
              {},
              headers_for(@user))

          last_response.status.should == 403
        end
      end
    end
  end
end
