require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::LegacyUsers do
    let(:admin) { Models::User.make(:admin => true) }
    let(:user_a) { Models::User.make(:admin => false ) }
    let(:user_b) { Models::User.make(:admin => false) }

    let(:admin_headers)  { headers_for(admin,  :email => "admin@vmware.com")  }
    let(:user_a_headers) { headers_for(user_a, :email => "user_a@vmware.com") }
    let(:user_b_headers) { headers_for(user_b, :email => "user_b@vmware.com") }

    context "as an unauthenticated user" do
      it "should return not authorized" do
        get "/users/user_a@vmware.com", {}, {}
        last_response.status.should == 403
      end
    end

    context "as an authenticated user fetching their own info" do
      it "should return the info for the user" do
        get "/users/user_a@VMware.com", {}, user_a_headers
        last_response.status.should == 200
        decoded_response["email"].should == "user_a@VMware.com"
        decoded_response["admin"].should == false
      end
    end

    context "as an authenticated user fetching a different user's info" do
      it "should return not authorized" do
        get "/users/user_b@VMware.com", {}, user_a_headers
        last_response.status.should == 403
      end
    end

    context "as an authenticated admin fetching their own info" do
      it "should return the info for the user" do
        get "/users/admin@VMware.com", {}, admin_headers
        last_response.status.should == 200
        decoded_response["email"].should == "admin@VMware.com"
        decoded_response["admin"].should == true
      end
    end

    context "as an authenticated admin fetching a different user's info" do
      it "should return not authorized" do
        get "/users/user_b@VMware.com", {}, admin_headers
        last_response.status.should == 403
      end
    end
  end
end
