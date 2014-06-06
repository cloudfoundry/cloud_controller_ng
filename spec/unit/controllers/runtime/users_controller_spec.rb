require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::UsersController do
    it_behaves_like "an admin only endpoint", path: "/v2/users"
    include_examples "enumerating objects", path: "/v2/users", model: User
    include_examples "reading a valid object", path: "/v2/users", model: User, basic_attributes: []
    include_examples "operations on an invalid object", path: "/v2/users"
    include_examples "creating and updating", path: "/v2/users", model: User, required_attributes: %w(guid), unique_attributes: %w(guid)
    include_examples "deleting a valid object", path: "/v2/users", model: User, one_to_many_collection_ids: {}
    include_examples "collection operations", path: "/v2/users", model: User,
                     one_to_many_collection_ids: {},
                     many_to_one_collection_ids: {
                         :default_space => lambda { |user|
                           org = user.organizations.first || Organization.make
                           Space.make(:organization => org)
                         }
                     },
                     many_to_many_collection_ids: {
                         organizations: lambda { |_| Organization.make },
                         billing_managed_organizations: lambda { |user|
                           org = Organization.make
                           user.add_organization(org)
                           org
                         },
                         audited_organizations: lambda { |user|
                           org = Organization.make
                           user.add_organization(org)
                           org
                         },
                         spaces: lambda { |user|
                           org = user.organizations.first || Organization.make
                           Space.make(organization: org)
                         },
                         managed_spaces: lambda { |user|
                           org = user.organizations.first || Organization.make
                           Space.make(organization: org)
                         },
                         audited_spaces: lambda { |user|
                           org = user.organizations.first || Organization.make
                           Space.make(organization: org)
                         }
                     }

    describe 'permissions' do
      include_context "permissions"
      before do
        @obj_a = member_a
        @obj_b = member_b
      end

      let(:creation_req_for_a) { Yajl::Encoder.encode(:guid => 'hi') }
      let(:update_req_for_a) { Yajl::Encoder.encode(:guid => @obj_a.guid) }

      context 'normal user' do
        let(:member_a) { @org_a_manager }
        let(:member_b) { @space_a_manager }
        include_examples "permission enumeration", "User",
                         :name => 'user',
                         :path => "/v2/users",
                         :enumerate => :not_allowed
      end

      context 'admin user' do
        let(:member_a) { @org_a_manager }
        let(:member_b) { @space_a_manager }
        let(:enumeration_expectation_a) { User.order(:id).limit(50) }
        let(:enumeration_expectation_b) { enumeration_expectation_a }

        before do
          VCAP::CloudController::SecurityContext.stub(:token).and_return({'scope' => ['cloud_controller.admin']})
        end

        include_examples "permission enumeration", "Admin",
                         :name => 'user',
                         :path => "/v2/users",
                         :enumerate => Proc.new { User.count },
                         :permissions_overlap => true
      end
    end
  end
end
