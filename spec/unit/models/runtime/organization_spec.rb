# encoding: utf-8
require "spec_helper"

module VCAP::CloudController
  describe Organization, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe "Associations" do
      it { is_expected.to have_associated :spaces }
      it { is_expected.to have_associated :private_domains, associated_instance: ->(org) { PrivateDomain.make(owning_organization: org) } }
      it { is_expected.to have_associated :service_plan_visibilities }
      it { is_expected.to have_associated :quota_definition }
      it { is_expected.to have_associated :domains, class: SharedDomain }
      it { is_expected.to have_associated :users }
      it { is_expected.to have_associated :managers, class: User }
      it { is_expected.to have_associated :billing_managers, class: User }
      it { is_expected.to have_associated :auditors, class: User }
      it { is_expected.to have_associated :space_quota_definitions, associated_instance: ->(org) { SpaceQuotaDefinition.make(organization: org) } }

      it "has associated apps" do
        app = App.make
        organization = app.space.organization
        expect(organization.apps).to include(app.reload)
      end

      it "has associated service_instances" do
        service_instance = ManagedServiceInstance.make
        organization = service_instance.space.organization
        expect(organization.service_instances).to include(service_instance.reload)
      end
    end

    describe "Validations" do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_uniqueness :name }
      it { is_expected.to strip_whitespace :name }

      describe "name" do
        subject(:org) { Organization.make }

        it "shoud allow standard ascii characters" do
          org.name = "A -_- word 2!?()\'\"&+."
          expect {
            org.save
          }.to_not raise_error
        end

        it "should allow backslash characters" do
          org.name = "a\\word"
          expect {
            org.save
          }.to_not raise_error
        end

        it "should allow unicode characters" do
          org.name = "防御力¡"
          expect {
            org.save
          }.to_not raise_error
        end

        it "should not allow newline characters" do
          org.name = "one\ntwo"
          expect {
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should not allow escape characters" do
          org.name = "a\e word"
          expect {
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe "managers" do
        subject(:org) { Organization.make }

        it "allows creating an org with no managers" do
          expect {
            org.save
          }.to_not raise_error
        end

        it "allows deleting a manager but leaving at least one manager behind" do
          u1, u2 = [User.make, User.make]
          org.manager_guids = [u1.guid, u2.guid]
          org.save

          org.manager_guids = [u1.guid]
          expect {
            org.save
          }.not_to raise_error
        end

        it "disallows removing all the managersjim" do
          u1, u2 = [User.make, User.make]
          org.manager_guids = [u1.guid]
          org.save

          expect {
            org.manager_guids = [u2.guid]
          }.not_to raise_error
        end

        it "disallows removing all the managers" do
          u1, u2 = [User.make, User.make]
          org.manager_guids = [u1.guid, u2.guid]
          org.save

          expect {
            org.manager_guids = []
          }.to raise_error(Sequel::HookFailed)
        end
      end

      describe "space_quota_definitions" do
        it "adds when in this org" do
          org = Organization.make
          quota = SpaceQuotaDefinition.make(organization: org)

          expect { org.add_space_quota_definition(quota) }.to_not raise_error
        end

        it "does not add when quota is in a different org" do
          org = Organization.make
          quota = SpaceQuotaDefinition.make

          expect { org.add_space_quota_definition(quota) }.to raise_error
        end
      end

      describe "private_domains" do
        it "adds the domain when it belongs to this org" do
          org = Organization.make
          domain = PrivateDomain.make(owning_organization: org)

          expect { org.add_private_domain(domain) }.to_not raise_error
        end

        it "does not add the domain when it belongs to a different org" do
          org = Organization.make
          domain = PrivateDomain.make

          expect { org.add_private_domain(domain) }.to raise_error
        end
      end
    end

    describe "Serialization" do
      it { is_expected.to export_attributes :name, :billing_enabled, :quota_definition_guid, :status }
      it { is_expected.to import_attributes :name, :billing_enabled, :user_guids, :manager_guids, :billing_manager_guids,
                                    :auditor_guids, :private_domain_guids, :quota_definition_guid, :status, :domain_guids }
    end

    context "statuses" do
      describe "when status == active" do
        subject(:org) { Organization.make(status: "active") }
        it("is active") { expect(org).to be_active }
        it("is not suspended") { expect(org).not_to be_suspended }
      end

      describe "when status == suspended" do
        subject(:org) { Organization.make(status: "suspended") }
        it("is not active") { expect(org).not_to be_active }
        it("is suspended") { expect(org).to be_suspended }
      end

      describe "when status == unknown" do
        subject(:org) { Organization.make(status: "unknown") }
        it("is not active") { expect(org).not_to be_active }
        it("is not suspended") { expect(org).not_to be_suspended }
      end
    end

    describe "billing" do
      it "should not be enabled for billing when first created" do
        expect(Organization.make.billing_enabled).to eq(false)
      end

      context "enabling billing" do
        before do
          TestConfig.override({ :billing_event_writing_enabled => true })
        end

        let (:org) do
          o = Organization.make
          2.times do
            space = Space.make(
              :organization => o,
            )
            2.times do
              AppFactory.make(
                :space => space,
                :state => "STARTED",
                :package_hash => "abc",
                :package_state => "STAGED",
              )
              AppFactory.make(
                :space => space,
                :state => "STOPPED",
              )
              ManagedServiceInstance.make(:space => space)
            end
          end
          o
        end

        it "should call OrganizationStartEvent.create_from_org" do
          expect(OrganizationStartEvent).to receive(:create_from_org)
          org.billing_enabled = true
          org.save(:validate => false)
        end

        it "should emit start events for running apps" do
          ds = AppStartEvent.filter(
            :organization_guid => org.guid,
          )
          org.billing_enabled = true
          org.save(:validate => false)
          expect(ds.count).to eq(4)
        end

        it "should emit create events for provisioned services" do
          ds = ServiceCreateEvent.filter(
            :organization_guid => org.guid,
          )
          org.billing_enabled = true
          org.save(:validate => false)
          expect(ds.count).to eq(4)
        end
      end
    end

    context "memory quota" do
      let(:quota) do
        QuotaDefinition.make(:memory_limit => 500)
      end

      it "should return the memory available when no apps are running" do
        org = Organization.make(:quota_definition => quota)

        expect(org.has_remaining_memory(500)).to eq(true)
        expect(org.has_remaining_memory(501)).to eq(false)
      end

      it "should return the memory remaining when apps are consuming memory" do
        org = Organization.make(:quota_definition => quota)
        space = Space.make(:organization => org)
        AppFactory.make(:space => space,
                        :memory => 200,
                        :instances => 2)
        AppFactory.make(:space => space,
                        :memory => 50,
                        :instances => 1)

        expect(org.has_remaining_memory(50)).to eq(true)
        expect(org.has_remaining_memory(51)).to eq(false)
      end
    end

    describe "#destroy" do
      subject(:org) { Organization.make }
      let(:space) { Space.make(:organization => org) }

      before { org.reload }

      it "destroys all apps" do
        app = AppFactory.make(:space => space)
        expect { org.destroy }.to change { App[:id => app.id] }.from(app).to(nil)
      end

      it "creates an AppUsageEvent for each app in the STARTED state" do
        app = AppFactory.make(space: space)
        app.update(state: "STARTED")
        expect {
          org.destroy
        }.to change {
          AppUsageEvent.count
        }.by(1)
        event = AppUsageEvent.last
        expect(event.app_guid).to eql(app.guid)
        expect(event.state).to eql("STOPPED")
        expect(event.org_guid).to eql(org.guid)
      end

      it "destroys all spaces" do
        expect { org.destroy }.to change { Space[:id => space.id] }.from(space).to(nil)
      end

      it "destroys all space quota definitions" do
        sqd = SpaceQuotaDefinition.make(organization: org)
        expect { org.destroy }.to change { SpaceQuotaDefinition[:id => sqd.id] }.from(sqd).to(nil)
      end

      it "destroys all service instances" do
        service_instance = ManagedServiceInstance.make(:space => space)
        expect { org.destroy }.to change { ManagedServiceInstance[:id => service_instance.id] }.from(service_instance).to(nil)
      end

      it "destroys all service plan visibilities" do
        service_plan_visibility = ServicePlanVisibility.make(:organization => org)
        expect {
          org.destroy
        }.to change {
          ServicePlanVisibility.where(:id => service_plan_visibility.id).any?
        }.to(false)
      end

      it "destroys private domains" do
        domain = PrivateDomain.make(:owning_organization => org)

        expect {
          org.destroy
        }.to change {
          Domain[:id => domain.id]
        }.from(domain).to(nil)
      end
    end

    describe "adding domains" do
      it "does not add domains to the organization if it is a shared domain" do
        shared_domain = SharedDomain.make
        org = Organization.make
        expect { org.add_domain(shared_domain) }.not_to change { org.domains }
      end

      it "does nothing if it is a private domain that belongs to the org" do
        org = Organization.make
        private_domain = PrivateDomain.make(owning_organization: org)
        expect { org.add_domain(private_domain) }.not_to change { org.domains.collect(&:id) }
      end

      it "raises error if the private domain does not belongs to the organization" do
        org = Organization.make
        private_domain = PrivateDomain.make(owning_organization: Organization.make)
        expect { org.add_domain(private_domain) }.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
      end
    end

    describe "#domains (eager loading)" do
      before { SharedDomain.dataset.destroy }

      it "is able to eager load domains" do
        org = Organization.make
        private_domain1 = PrivateDomain.make(owning_organization: org)
        private_domain2 = PrivateDomain.make(owning_organization: org)
        shared_domain = SharedDomain.make

        expect {
          @eager_loaded_org = Organization.eager(:domains).where(id: org.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          @eager_loaded_domains = @eager_loaded_org.domains.to_a
        }.to have_queried_db_times(//, 0)

        expect(@eager_loaded_org).to eql(org)
        expect(@eager_loaded_domains).to match_array([private_domain1, private_domain2, shared_domain])
        expect(@eager_loaded_domains).to match_array(org.domains)
      end

      it "has correct domains for each org" do
        org1 = Organization.make
        org2 = Organization.make

        private_domain1 = PrivateDomain.make(owning_organization: org1)
        private_domain2 = PrivateDomain.make(owning_organization: org2)
        shared_domain = SharedDomain.make

        expect {
          @eager_loaded_orgs = Organization.eager(:domains).where(id: [org1.id, org2.id]).limit(2).all
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_orgs[0].domains).to match_array([private_domain1, shared_domain])
          expect(@eager_loaded_orgs[1].domains).to match_array([private_domain2, shared_domain])
        }.to have_queried_db_times(//, 0)
      end

      it "passes in dataset to be loaded to eager_block option" do
        org1 = Organization.make

        private_domain1 = PrivateDomain.make(owning_organization: org1)
        private_domain2 = PrivateDomain.make(owning_organization: org1)

        eager_block = proc { |ds| ds.where(id: private_domain1.id) }

        expect {
          @eager_loaded_org = Organization.eager(domains: eager_block).where(id: org1.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect(@eager_loaded_org.domains).to eql([private_domain1])
      end

      it "allow nested eager_load" do
        org = Organization.make
        space = Space.make(organization: org)

        domain1 = PrivateDomain.make(owning_organization: org)
        domain2 = PrivateDomain.make(owning_organization: org)

        route1 = Route.make(domain: domain1, space: space)
        route2 = Route.make(domain: domain2, space: space)

        expect {
          @eager_loaded_org = Organization.eager(domains: :routes).where(id: org.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_org.domains[0].routes).to eql([route1])
          expect(@eager_loaded_org.domains[1].routes).to eql([route2])
        }.to have_queried_db_times(//, 0)
      end
    end

    describe "removing a user" do
      let(:org)     { Organization.make }
      let(:user)    { User.make }
      let(:space_1) { Space.make }
      let(:space_2) { Space.make }

      before do
        org.add_user(user)
        org.add_space(space_1)
      end

      context "without the recursive flag (#remove_user)" do
        it "should raise an error if the user's developer space is associated with an organization's space" do
          space_1.add_developer(user)
          space_1.refresh
          expect(user.spaces).to include(space_1)
          expect { org.remove_user(user) }.to raise_error(VCAP::Errors::ApiError)
        end

        it "should raise an error if the user's managed space is associated with an organization's space" do
          space_1.add_manager(user)
          space_1.refresh
          expect(user.managed_spaces).to include(space_1)
          expect { org.remove_user(user) }.to raise_error(VCAP::Errors::ApiError)
        end

        it "should raise an error if the user's audited space is associated with an organization's space" do
          space_1.add_auditor(user)
          space_1.refresh
          expect(user.audited_spaces).to include(space_1)
          expect { org.remove_user(user) }.to raise_error(VCAP::Errors::ApiError)
        end

        it "should raise an error if any of the user's spaces are associated with any of the organization's spaces" do
          org.add_space(space_2)
          space_2.add_manager(user)
          space_2.refresh
          expect(user.managed_spaces).to include(space_2)
          expect { org.remove_user(user) }.to raise_error(VCAP::Errors::ApiError)
        end

        it "should remove the user from an organization if they are not associated with any spaces" do
          expect { org.remove_user(user) }.to change{ org.reload.user_guids }.from([user.guid]).to([])
        end
      end

      context "with the recursive flag (#remove_user_recursive)" do
        before do
          org.add_space(space_2)
          [space_1, space_2].each { |space| space.add_developer(user) }
          [space_1, space_2].each { |space| space.add_manager(user) }
          [space_1, space_2].each { |space| space.add_auditor(user) }
          [space_1, space_2].each { |space| space.refresh }
        end

        it "should remove the space developer roles from the user" do
          expect { org.remove_user_recursive(user) }.to change{ user.spaces.length}.from(2).to(0)
        end

        it "should remove the space manager roles from the user" do
          expect { org.remove_user_recursive(user) }.to change{ user.managed_spaces.length}.from(2).to(0)
        end

        it "should remove the space audited roles from the user" do
          expect { org.remove_user_recursive(user) }.to change{ user.audited_spaces.length}.from(2).to(0)
        end

        it "should remove the user from each spaces developer role" do
          [space_1, space_2].each { |space| expect(space.developers).to include(user) }
          org.remove_user_recursive(user)
          [space_1, space_2].each { |space| space.refresh }
          [space_1, space_2].each { |space| expect(space.developers).not_to include(user) }
        end

        it "should remove the user from each spaces manager role" do
          [space_1, space_2].each { |space| expect(space.managers).to include(user) }
          org.remove_user_recursive(user)
          [space_1, space_2].each { |space| space.refresh }
          [space_1, space_2].each { |space| expect(space.managers).not_to include(user) }
        end

        it "should remove the user from each spaces auditor role" do
          [space_1, space_2].each { |space| expect(space.auditors).to include(user) }
          org.remove_user_recursive(user)
          [space_1, space_2].each { |space| space.refresh }
          [space_1, space_2].each { |space| expect(space.auditors).not_to include(user) }
        end
      end
    end

    describe "#add_default_quota" do
      context "when the default quota exists" do
        let (:my_quota)  { QuotaDefinition.make }

        it "uses the one provided" do
          subject.quota_definition_id = my_quota.id
          subject.add_default_quota
          expect(subject.quota_definition_id).to eq(my_quota.id)
        end

        it "uses the default when nothing is provided" do
          subject.quota_definition_id = nil
          subject.add_default_quota
          expect(subject.quota_definition_id).to eq(QuotaDefinition.default.id)
        end
      end

      context "when the default quota does not exist" do
        before { QuotaDefinition.default.destroy }

        it "raises an exception" do
          subject.quota_definition_id = nil
          expect { subject.add_default_quota }.to raise_exception VCAP::Errors::ApiError, /Quota Definition could not be found/
        end
      end
    end
  end
end
