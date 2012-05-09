# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Permissions do
  let(:user) { VCAP::CloudController::Models::User.make }
  let(:admin) { VCAP::CloudController::Models::User.make(:admin => true) }

  describe "#permissions_for" do
    it "should return [Permission::Anonymous] only for a nil user" do
      Permissions.permissions_for(nil).should == [Permissions::Anonymous]
    end

    it "should return [Permission::Authenticated] for a standard user" do
      Permissions.permissions_for(user).should == [Permissions::Authenticated]
    end

    it "should return [Permission::Authenticated, Permission::CFAdmin] for an admin" do
      Permissions.permissions_for(admin).should == [Permissions::Authenticated,
                                                   Permissions::CFAdmin]
    end
  end
end
