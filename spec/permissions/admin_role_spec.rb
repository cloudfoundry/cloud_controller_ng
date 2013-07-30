require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::SecurityContext do
    describe "permissions" do

      before(:all) do
        @admin_token = {'scope' => ['cloud_controller.admin']}
        @plain_token = {'scope' => ['openid']}
        @admin_user = Models::User.make(:admin => true)
        @plain_user = Models::User.make(:admin => false)
      end

      it "should use scope for user lookup" do
        SecurityContext.set(@plain_user, @admin_token)
        SecurityContext.current_user_is_admin?.should == true
      end

      it "should report non-admin" do
        SecurityContext.set(@plain_user, @plain_token)
        SecurityContext.current_user_is_admin?.should == false
      end

    end
  end
end
