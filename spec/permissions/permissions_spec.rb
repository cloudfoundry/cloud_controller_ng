# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Permissions do
    let(:obj) { Models::Organization.make }
    let(:user) { Models::User.make }
    let(:admin) { Models::User.make(:admin => true) }

    describe "#permissions_for" do
      it "should return [Permission::Anonymous] only for a nil user" do
        Permissions.permissions_for(obj, nil).should == [Permissions::Anonymous]
      end

      it "should return [Permission::Authenticated] for a standard user" do
        Permissions.permissions_for(obj, user).should == [Permissions::Authenticated]
      end

      it "should return [Permission::Authenticated, Permission::CFAdmin] for an admin" do
        Permissions.permissions_for(obj, admin).sort_by { |klass| klass.name }.
          should == [Permissions::Authenticated, Permissions::CFAdmin]
      end
    end
  end
end
