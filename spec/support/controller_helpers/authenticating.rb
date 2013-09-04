# Copyright (c) 2009-2012 VMware, Inc.

module ControllerHelpers
  shared_examples "uaa authenticated api" do |opts|
    context "with invalid auth header" do
      before(:all) do
        headers = headers_for(User.make)
        headers["HTTP_AUTHORIZATION"] += "EXTRA STUFF"
        get opts[:path], {}, headers
      end

      it "should return 401" do
        last_response.status.should == 401
      end

      it "should reutrn a vcap error code of 1000" do
        decoded_response["code"].should == 1000
      end

      it_behaves_like "a vcap rest error response", /Invalid Auth Token/
    end

    context "with valid auth header" do
      context "for an existing user" do
        it "should return 200" do
          get opts[:path], {}, headers_for(User.make)
          last_response.status.should == 200 # finds the user
        end
      end

      context "for a new user" do
        it "should return 200" do
          get opts[:path], {}, headers_for(Machinist.with_save_nerfed { User.make })
          last_response.status.should == 200 # creates the user
        end
      end

      context "for an admin" do
        it "should return 200" do
          get opts[:path], {}, headers_for(nil, :admin_scope => true)
          last_response.status.should == 200 # creates the admin
        end
      end

      context "for no user" do
        it "should return 401" do
          get opts[:path], {}, headers_for(nil)
          last_response.status.should == 401
        end
      end

      context "for a deleted user" do
        it "should return 200" do
          user = User.make
          headers = headers_for(user)
          user.delete
          get opts[:path], {}, headers
          last_response.status.should == 200 # recreates the user
        end
      end
    end
  end
end
