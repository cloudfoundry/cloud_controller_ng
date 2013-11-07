require "spec_helper"

module VCAP::CloudController
  describe UserProvidedServiceInstancesController, :services, type: :controller do
    include_examples "creating", path: "/v2/user_provided_service_instances",
                     model: UserProvidedServiceInstance,
                     required_attributes: %w(name space_guid),
                     unique_attributes: %w(space_guid name)
    include_examples "collection operations", path: "/v2/user_provided_service_instances", model: UserProvidedServiceInstance,
      one_to_many_collection_ids: {
        service_bindings: lambda { |service_instance| make_service_binding_for_service_instance(service_instance) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}
    include_examples "deleting a valid object", path: "/v2/user_provided_service_instances", model: UserProvidedServiceInstance,
      one_to_many_collection_ids: {
        :service_bindings => lambda { |service_instance|
          make_service_binding_for_service_instance(service_instance)
        }
      }

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = UserProvidedServiceInstance.make(:space => @space_a)
        @obj_b = UserProvidedServiceInstance.make(:space => @space_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :name => Sham.name,
          :space_guid => @space_a.guid,
          :credentials => {"foopass" => "barpass"}
        )
      end
      let(:update_req_for_a) {"{}"} # update is not implemented

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

    it "allows creation of empty credentials with a syslog drain" do
      space = Space.make
      json_body = Yajl::Encoder.encode({
        name: "name",
        space_guid: space.guid,
        syslog_drain_url: "syslog://example.com",
        credentials: {}
      })

      post "/v2/user_provided_service_instances", json_body.to_s, json_headers(admin_headers)
      last_response.status.should == 201

      UserProvidedServiceInstance.last.syslog_drain_url.should == "syslog://example.com"
    end
  end
end
