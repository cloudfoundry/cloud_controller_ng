require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Permissions do
    let(:obj) { Models::Organization.make }
    let(:user) { Models::User.make }
    let(:admin) { Models::User.make(:admin => true) }
    let(:no_role) { VCAP::CloudController::Roles.new }
    let(:admin_role) { VCAP::CloudController::Roles.new.tap{|r| r.admin = true} }

    describe "#permissions_for" do
      it "should return [Permission::Anonymous] only for a nil user" do
        Permissions.permissions_for(obj, nil, no_role).should == [Permissions::Anonymous]
      end

      it "should return [Permission::Authenticated] for a standard user" do
        Permissions.permissions_for(obj, user, no_role).should == [Permissions::Authenticated]
      end

      it "should return [Permission::Authenticated, Permission::CFAdmin] for an admin" do
        Permissions.permissions_for(obj, admin, no_role).sort_by { |klass| klass.name }.
          should == [Permissions::Authenticated, Permissions::CFAdmin]
      end

      it "should return [Permission::Authenticated, Permission::CFAdmin] for an entity with an admin role" do
        [nil, user, admin].each do |u|
          Permissions.permissions_for(obj, admin, no_role).sort_by { |klass| klass.name }.
            should == [Permissions::Authenticated, Permissions::CFAdmin]
        end
      end
    end
  end
end
