module ControllerHelpers
  shared_context "permissions" do
    let(:headers_a) { headers_for(member_a) }
    let(:headers_b) { headers_for(member_b) }

    before do
      @org_a = Organization.make
      @org_a_manager = User.make
      @org_a_member = User.make
      @org_a_billing_manager = User.make
      @org_a_auditor = User.make
      @org_a.add_user(@org_a_manager)
      @org_a.add_user(@org_a_member)
      @org_a.add_user(@org_a_billing_manager)
      @org_a.add_user(@org_a_auditor)
      @org_a.add_manager(@org_a_manager)
      @org_a.add_billing_manager(@org_a_billing_manager)
      @org_a.add_auditor(@org_a_auditor)

      @space_a = Space.make(:organization => @org_a)
      @space_a_manager = make_user_for_space(@space_a)
      @space_a_developer = make_user_for_space(@space_a)
      @space_a_auditor = make_user_for_space(@space_a)
      @space_a.add_manager(@space_a_manager)
      @space_a.add_developer(@space_a_developer)
      @space_a.add_auditor(@space_a_auditor)

      @org_b = Organization.make
      @org_b_manager = User.make
      @org_b_member = User.make
      @org_b_billing_manager = User.make
      @org_b_auditor = User.make
      @org_b.add_user(@org_b_manager)
      @org_b.add_user(@org_b_member)
      @org_b.add_user(@org_b_billing_manager)
      @org_b.add_user(@org_b_auditor)
      @org_b.add_manager(@org_b_manager)
      @org_b.add_billing_manager(@org_b_billing_manager)
      @org_b.add_auditor(@org_b_auditor)

      @space_b = Space.make(:organization => @org_b)
      @space_b_manager = make_user_for_space(@space_b)
      @space_b_developer = make_user_for_space(@space_b)
      @space_b_auditor = make_user_for_space(@space_b)
      @space_b.add_manager(@space_b_manager)
      @space_b.add_developer(@space_b_developer)
      @space_b.add_auditor(@space_b_auditor)

      @cf_admin = User.make(:admin => true)
    end
  end


  shared_examples "permission enumeration" do |perm_name, opts|
    name = opts[:name]
    path = opts[:path]
    path_suffix = opts[:path_suffix]
    expected = opts[:enumerate]
    perms_overlap = opts[:permissions_overlap]
    describe "GET #{path}" do
      it "should return #{name.pluralize} to a user that has #{perm_name} permissions" do
        expected_count = expected.respond_to?(:call) ? expected.call : expected
        get path, {}, headers_a
        if expected_count == :not_allowed
          last_response.status.should == 403
        else
          last_response.should be_ok
          decoded_response["total_results"].should == expected_count
          guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
          if respond_to?(:enumeration_expectation_a)
            guids.sort.should == enumeration_expectation_a.map(&:guid).sort
          else
            guids.should include(@obj_a.guid) if expected_count > 0
          end
        end

        get path, {}, headers_b
        if expected_count == :not_allowed
          last_response.status.should == 403
        else
          decoded_response["total_results"].should == expected_count
          guids = decoded_response["resources"].map { |o| o["metadata"]["guid"] }
          if respond_to?(:enumeration_expectation_b)
            expect(guids.sort).to eq enumeration_expectation_b.map(&:guid).sort
          else
            guids.should include(@obj_b.guid) if expected_count > 0
          end
        end
      end

      unless perms_overlap
        it "should not return a #{name} to a user with the #{perm_name} permission on a different #{name}" do
          get "#{path}/#{@obj_a.guid}#{path_suffix}", {}, headers_b
          last_response.should_not be_ok
        end
      end
    end
  end
end
