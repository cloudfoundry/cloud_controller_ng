shared_context "permissions" do
  let(:headers_a) { headers_for(member_a) }
  let(:headers_b) { headers_for(member_b) }

  before do
    @org_a = VCAP::CloudController::Organization.make
    @org_a_manager = VCAP::CloudController::User.make
    @org_a_member = VCAP::CloudController::User.make
    @org_a_billing_manager = VCAP::CloudController::User.make
    @org_a_auditor = VCAP::CloudController::User.make
    @org_a.add_user(@org_a_manager)
    @org_a.add_user(@org_a_member)
    @org_a.add_user(@org_a_billing_manager)
    @org_a.add_user(@org_a_auditor)
    @org_a.add_manager(@org_a_manager)
    @org_a.add_billing_manager(@org_a_billing_manager)
    @org_a.add_auditor(@org_a_auditor)

    @space_a = VCAP::CloudController::Space.make(:organization => @org_a)
    @space_a_manager = make_user_for_space(@space_a)
    @space_a_developer = make_user_for_space(@space_a)
    @space_a_auditor = make_user_for_space(@space_a)
    @space_a.add_manager(@space_a_manager)
    @space_a.add_developer(@space_a_developer)
    @space_a.add_auditor(@space_a_auditor)

    @org_b = VCAP::CloudController::Organization.make
    @org_b_manager = VCAP::CloudController::User.make
    @org_b_member = VCAP::CloudController::User.make
    @org_b_billing_manager = VCAP::CloudController::User.make
    @org_b_auditor = VCAP::CloudController::User.make
    @org_b.add_user(@org_b_manager)
    @org_b.add_user(@org_b_member)
    @org_b.add_user(@org_b_billing_manager)
    @org_b.add_user(@org_b_auditor)
    @org_b.add_manager(@org_b_manager)
    @org_b.add_billing_manager(@org_b_billing_manager)
    @org_b.add_auditor(@org_b_auditor)

    @space_b = VCAP::CloudController::Space.make(:organization => @org_b)
    @space_b_manager = make_user_for_space(@space_b)
    @space_b_developer = make_user_for_space(@space_b)
    @space_b_auditor = make_user_for_space(@space_b)
    @space_b.add_manager(@space_b_manager)
    @space_b.add_developer(@space_b_developer)
    @space_b.add_auditor(@space_b_auditor)

    @cf_admin = VCAP::CloudController::User.make(:admin => true)
  end
end


shared_examples "permission enumeration" do |perm_name, opts|
  name = opts[:name]
  path = opts[:path]
  expected = opts[:enumerate]
  perms_overlap = opts[:permissions_overlap]
  describe "GET #{path}" do
    it "should return #{name.pluralize} to a user that has #{perm_name} permissions" do
      expected_count = expected.respond_to?(:call) ? expected.call : expected
      get path, {}, headers_a
      if expected_count == :not_allowed
        expect(last_response.status).to eq(403)
      else
        expect(last_response).to be_ok
        expect(decoded_response["total_results"]).to eq(expected_count)
        guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
        if respond_to?(:enumeration_expectation_a)
          expect(guids.sort).to eq enumeration_expectation_a.map(&:guid).sort
        else
          expect(guids).to include(@obj_a.guid) if expected_count > 0
        end
      end
    end

    unless perms_overlap
      it "should not return a #{name} to a user with the #{perm_name} permission on a different #{name}" do
        get "#{path}/#{@obj_a.guid}", {}, headers_b
        expect(last_response).not_to be_ok
      end
    end
  end
end
