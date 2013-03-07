# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ApiSpecHelper
  shared_examples "uaa authenticated api" do |opts|
    context "with invalid auth header" do
      before(:all) do
        headers = headers_for(Models::User.make)
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
      context "for a known user" do
        it "should return 200" do
          get opts[:path], {}, headers_for(Models::User.make)
          last_response.status.should == 200
        end
      end

      context "for an admin client" do
        it "should return 200" do
          get opts[:path], {}, headers_for(nil, :admin_scope => true)
          last_response.status.should == 200
        end
      end

      context "for a non-admin client" do
        it "should return 401" do
          get opts[:path], {}, headers_for(nil)
          last_response.status.should == 401
        end
      end

      context "for an unknown user" do
        before(:all) do
          user = Models::User.make
          headers = headers_for(user)
          user.delete
          get opts[:path], {}, headers
        end

        it "should return 403" do
          last_response.status.should == 403
        end

        it_behaves_like "a vcap rest error response", /You are not authorized/
      end
    end
  end
end
