# encoding: utf-8
require "spec_helper"

module VCAP::CloudController
  describe Organization, type: :model do
    it_behaves_like "a CloudController model", {
      required_attributes: :name,
      unique_attributes: :name,
      custom_attributes_for_uniqueness_tests: -> { { quota_definition: QuotaDefinition.make } },
      stripped_string_attributes: :name,
      many_to_zero_or_more: {
        users: ->(_) { User.make },
        managers: ->(_) { User.make },
        billing_managers: ->(_) { User.make },
        auditors: ->(_) { User.make },
      },
      one_to_zero_or_more: {
        spaces: ->(_) { Space.make },
        domains: ->(org) { PrivateDomain.make(owning_organization: org) },
        private_domains: ->(org) { PrivateDomain.make(owning_organization: org) }
      }
    }

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

    describe "validations" do
      context "name" do
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

      context "managers" do
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
    end

    describe "billing" do
      it "should not be enabled for billing when first created" do
        Organization.make.billing_enabled.should == false
      end

      context "enabling billing" do
        before do
          config_override({ :billing_event_writing_enabled => true })
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
          OrganizationStartEvent.should_receive(:create_from_org)
          org.billing_enabled = true
          org.save(:validate => false)
        end

        it "should emit start events for running apps" do
          ds = AppStartEvent.filter(
            :organization_guid => org.guid,
          )
          org.billing_enabled = true
          org.save(:validate => false)
          ds.count.should == 4
        end

        it "should emit create events for provisioned services" do
          ds = ServiceCreateEvent.filter(
            :organization_guid => org.guid,
          )
          org.billing_enabled = true
          org.save(:validate => false)
          ds.count.should == 4
        end
      end
    end

    context "memory quota" do
      let(:quota) do
        QuotaDefinition.make(:memory_limit => 500)
      end

      it "should return the memory available when no apps are running" do
        org = Organization.make(:quota_definition => quota)

        org.memory_remaining.should == 500
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

        org.memory_remaining.should == 50
      end
    end

    describe "#destroy" do
      subject(:org) { Organization.make }
      let(:space) { Space.make(:organization => org) }

      before { org.reload }

      it "destroys all apps" do
        app = AppFactory.make(:space => space)
        expect { org.destroy(savepoint: true) }.to change { App[:id => app.id] }.from(app).to(nil)
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
        expect { org.destroy(savepoint: true) }.to change { Space[:id => space.id] }.from(space).to(nil)
      end

      it "destroys all service instances" do
        service_instance = ManagedServiceInstance.make(:space => space)
        expect { org.destroy(savepoint: true) }.to change { ManagedServiceInstance[:id => service_instance.id] }.from(service_instance).to(nil)
      end

      it "destroys all service plan visibilities" do
        service_plan_visibility = ServicePlanVisibility.make(:organization => org)
        expect {
          org.destroy(savepoint: true)
        }.to change {
          ServicePlanVisibility.where(:id => service_plan_visibility.id).any?
        }.to(false)
      end

      it "destroys private domains" do
        domain = PrivateDomain.make(:owning_organization => org)

        expect {
          org.destroy(savepoint: true)
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
      before { SharedDomain.dataset.delete }

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
        expect(@eager_loaded_domains).to eql([private_domain1, private_domain2, shared_domain])
        expect(@eager_loaded_domains).to eql(org.domains)
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
  end
end
