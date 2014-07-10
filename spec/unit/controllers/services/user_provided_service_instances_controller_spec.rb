require "spec_helper"

module VCAP::CloudController
  describe UserProvidedServiceInstancesController, :services do

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          name: {type: "string", required: true},
          credentials: {type: "hash", default: {}},
          syslog_drain_url: {type: "string", default: ""},
          space_guid: {type: "string", required: true},
          service_binding_guids: {type: "[string]"}
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: {type: "string"},
          credentials: {type: "hash"},
          syslog_drain_url: {type: "string"},
          space_guid: {type: "string"},
          service_binding_guids: {type: "[string]"}
        })
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = UserProvidedServiceInstance.make(:space => @space_a)
        @obj_b = UserProvidedServiceInstance.make(:space => @space_b)
      end

      def self.user_sees_empty_enumerate(user_role, member_a_ivar, member_b_ivar)
        describe user_role do
          let(:member_a) { instance_variable_get(member_a_ivar) }
          let(:member_b) { instance_variable_get(member_b_ivar) }

          include_examples "permission enumeration", user_role,
                           :name => 'user provided service instance',
                           :path => "/v2/user_provided_service_instances",
                           :enumerate => 0
        end
      end

      describe "Org Level Permissions" do
        user_sees_empty_enumerate("OrgManager",     :@org_a_manager,         :@org_b_manager)
        user_sees_empty_enumerate("OrgUser",        :@org_a_member,          :@org_b_member)
        user_sees_empty_enumerate("BillingManager", :@org_a_billing_manager, :@org_b_billing_manager)
        user_sees_empty_enumerate("Auditor",        :@org_a_auditor,         :@org_b_auditor)
      end

      describe "App Space Level Permissions" do
        user_sees_empty_enumerate("SpaceManager", :@space_a_manager, :@space_b_manager)

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission enumeration", "Developer",
                           :name => 'user provided service instance',
                           :path => "/v2/user_provided_service_instances",
                           :enumerate => 1
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission enumeration", "SpaceAuditor",
                           :name => 'user provided service instance',
                           :path => "/v2/user_provided_service_instances",
                           :enumerate => 1
        end
      end
    end
  end
end
