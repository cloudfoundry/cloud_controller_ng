require_relative 'spec_helper'

module VCAP::CloudController
  describe UserProvidedServiceInstance do
    include_examples "creating", path: "/v2/user_provided_service_instances",
                     model: Models::UserProvidedServiceInstance,
                     required_attributes: %w(name space_guid credentials),
                     unique_attributes: %w(space_guid name)

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = Models::UserProvidedServiceInstance.make(:space => @space_a)
        @obj_b = Models::UserProvidedServiceInstance.make(:space => @space_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :name => Sham.name,
          :space_guid => @space_a.guid,
          :credentials => {"foopass" => "barpass"}
        )
      end
      let(:update_req_for_a) {"{}"} # update is not implemented

      def self.user_does_not_have_access(user_role, member_a_ivar, member_b_ivar)
        describe user_role do
          let(:member_a) { instance_variable_get(member_a_ivar) }
          let(:member_b) { instance_variable_get(member_b_ivar) }

          include_examples "permission checks", user_role,
                           :model => Models::UserProvidedServiceInstance,
                           :path => "/v2/user_provided_service_instances",
                           :enumerate => 0,
                           :create => :not_allowed,
                           :read => :not_allowed,
                           :modify => :not_allowed,
                           :delete => :not_allowed
        end
      end

      describe "Org Level Permissions" do
        user_does_not_have_access("OrgManager",     :@org_a_manager,         :@org_b_manager)
        user_does_not_have_access("OrgUser",        :@org_a_member,          :@org_b_member)
        user_does_not_have_access("BillingManager", :@org_a_billing_manager, :@org_b_billing_manager)
        user_does_not_have_access("Auditor",        :@org_a_auditor,         :@org_b_auditor)
      end

      describe "App Space Level Permissions" do
        user_does_not_have_access("SpaceManager", :@space_a_manager, :@space_b_manager)

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
                           :model => Models::UserProvidedServiceInstance,
                           :path => "/v2/user_provided_service_instances",
                           :enumerate => 1,
                           :create => :allowed,
                           :read => :allowed,
                           :modify => :allowed,
                           :delete => :allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission checks", "SpaceAuditor",
                           :model => Models::UserProvidedServiceInstance,
                           :path => "/v2/user_provided_service_instances",
                           :enumerate => 0,
                           :create => :not_allowed,
                           :read => :allowed,
                           :modify => :not_allowed,
                           :delete => :not_allowed
      end

      end

    end
  end
end
