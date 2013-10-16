require "spec_helper"
require "vcap/component"
require "cloud_controller/varz"

module VCAP::CloudController
  describe Varz do

    it "should include the number of users in varz" do
      # We have to use stubbing here because when we run in parallel mode,
      # there might other tests running and create/delete users concurrently.
      User.stub(:count).and_return(0)
      VCAP::Component.varz.synchronize do
        VCAP::Component.varz[:cc_user_count] = 0
      end

      User.stub(:count).and_return(4)
      Varz.bump_user_count

      VCAP::Component.varz.synchronize do
        VCAP::Component.varz[:cc_user_count].should == 4
      end
    end
  end
end