require "spec_helper"
require "vcap/component"
require "cloud_controller/varz"

module VCAP::CloudController
  describe Varz do
    it "should include the number of users in varz" do
      VCAP::Component.varz.synchronize do
        VCAP::Component.varz[:cc_user_count] = 0
      end

      4.times { VCAP::CloudController::User.make }
      Varz.bump_user_count

      VCAP::Component.varz.synchronize do
        VCAP::Component.varz[:cc_user_count].should == 4
      end
    end
  end
end