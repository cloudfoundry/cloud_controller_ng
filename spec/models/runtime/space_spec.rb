# encoding: utf-8
require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Space, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :organization],
      :unique_attributes   => [ [:organization, :name] ],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :organization      => {
          :delete_ok => true,
          :create_for => lambda { |space| Organization.make }
        }
      },
      :one_to_zero_or_more => {
        :apps              => {
          :delete_ok => true,
          :create_for => lambda { |space| AppFactory.make }
        },
        :service_instances => {
          :delete_ok => true,
          :create_for => lambda { |space| ManagedServiceInstance.make }
        },
        :routes            => {
          :delete_ok => true,
          :create_for => lambda { |space| Route.make(:space => space) }
        },
      },
      :many_to_zero_or_more => {
        :developers        => lambda { |space| make_user_for_space(space) },
        :managers          => lambda { |space| make_user_for_space(space) },
        :auditors          => lambda { |space| make_user_for_space(space) },
      }
    }

    describe "#in_suspended_org?" do
      let(:org) { Organization.make }
      subject(:space) { Space.new(organization: org) }

      context "when in a suspended organization" do
        before { allow(org).to receive(:suspended?).and_return(true) }
        it "is true" do
          expect(space).to be_in_suspended_org
        end
      end
      
      context "when in an unsuspended organization" do
        before { allow(org).to receive(:suspended?).and_return(false) }
        it "is false" do
          expect(space).not_to be_in_suspended_org
        end
      end
    end

    describe "validations" do
      context "name" do
        subject(:space) { Space.make }

        it "should allow standard ascii character" do
          space.name = "A -_- word 2!?()\'\"&+."
          expect{
            space.save
          }.to_not raise_error
        end

        it "should allow backslash character" do
          space.name = "a\\word"
          expect{
            space.save
          }.to_not raise_error
        end

        it "should allow unicode characters" do
          space.name = "防御力¡"
          expect{
            space.save
          }.to_not raise_error
        end

        it "should not allow newline character" do
          space.name = "a \n word"
          expect{
            space.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should not allow escape character" do
          space.name = "a \e word"
          expect{
            space.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end
    end

    context "bad relationships" do
      subject(:space) { Space.make }

      shared_examples "bad app space permission" do |perm|
        context perm do
          it "should not get associated with a #{perm.singularize} that isn't a member of the org" do
            exception = Space.const_get("Invalid#{perm.camelize}Relation")
            wrong_org = Organization.make
            user = make_user_for_org(wrong_org)

            expect {
              space.send("add_#{perm.singularize}", user)
            }.to raise_error exception
          end
        end
      end

      %w[developer manager auditor].each do |perm|
        include_examples "bad app space permission", perm
      end
    end

    describe "data integrity" do
      it "should not make strings into integers" do
        space = Space.make
        space.name.should be_kind_of(String)
        space.name = "1234"
        space.name.should be_kind_of(String)
        space.save
        space.refresh
        space.name.should be_kind_of(String)
      end
    end

    describe "#destroy" do
      subject(:space) { Space.make }

      it "creates an AppUsageEvent for each app in the STARTED state" do
        app = AppFactory.make(space: space)
        app.update(state: "STARTED")
        expect {
          subject.destroy
        }.to change {
          AppUsageEvent.count
        }.by(1)
        event = AppUsageEvent.last
        expect(event.app_guid).to eql(app.guid)
        expect(event.state).to eql("STOPPED")
        expect(event.space_name).to eql(space.name)
      end

      it "destroys all service instances" do
        service_instance = ManagedServiceInstance.make(:space => space)

        expect {
          subject.destroy(savepoint: true)
        }.to change {
          ManagedServiceInstance.where(id: service_instance.id).count
        }.by(-1)
      end

      it "destroys all routes" do
        route = Route.make(space: space)
        expect {
          subject.destroy(savepoint: true)
        }.to change {
          Route.where(id: route.id).count
        }.by(-1)
      end

      it "doesn't do anything to domains" do
        PrivateDomain.make(owning_organization: space.organization)
        expect {
          subject.destroy(savepoint: true)
        }.not_to change {
          space.organization.domains
        }
      end

      it "nullifies any default_users" do
        user = User.make
        space.add_default_user(user)
        space.save
        expect { subject.destroy(savepoint: true) }.to change { user.reload.default_space }.from(space).to(nil)
      end

      it "does not destroy any events related to the space" do
        event = Event.make(space: space)

        expect {
          subject.destroy(savepoint: true)
        }.to_not change {
          Event.where(id: [event.id]).count
        }

        event = Event.find(id: event.id)
        expect(event).to be
        expect(event.space).to be_nil
      end
    end

    describe "domains" do
      subject(:space) { Space.make() }

      context "listing domains" do
        let!(:domains) do
          [
            PrivateDomain.make(owning_organization: space.organization),
            SharedDomain.make
          ]
        end

        it "should list the owning organization's domains and shared domains" do
          expect(space.domains).to match_array(domains)
        end
      end

      context "adding domains" do
        it "does not add the domain to the space if it is a shared domain" do
          shared_domain = SharedDomain.make
          expect { space.add_domain(shared_domain) }.not_to change { space.domains }
        end

        it "does nothing if the private domain already belongs to the space's org" do
          org = Organization.make
          private_domain = PrivateDomain.make(owning_organization: org)
          space = Space.make(organization: org)
          expect { space.add_domain(private_domain) }.not_to change { space.domains }
        end

        it "reports an error if the private domain belongs to another org" do
          space_org = Organization.make
          space = Space.make(organization: space_org)

          domain_org = Organization.make
          private_domain = PrivateDomain.make(owning_organization: domain_org)
          expect { space.add_domain(private_domain) }.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
        end
      end
    end

    describe "#domains (eager loading)" do
      before do
        @model_manger = VCAP::CloudController::ModelManager.new(
            Space, PrivateDomain, SharedDomain
        )
        @model_manger.record
      end

      after do
        @model_manger.destroy
      end

      it "is able to eager load domains" do
        space = Space.make

        org = space.organization

        private_domain1 = PrivateDomain.make(owning_organization: org)
        private_domain2 = PrivateDomain.make(owning_organization: org)

        shared_domain = SharedDomain.make

        expect {
          @eager_loaded_space = Space.eager(:domains).where(id: space.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          @eager_loaded_domains = @eager_loaded_space.domains.to_a
        }.to have_queried_db_times(//, 0)

        expect(@eager_loaded_space).to eql(space)
        expect(@eager_loaded_domains).to eql([private_domain1, private_domain2, shared_domain])
        expect(@eager_loaded_domains).to eql(org.domains)
      end

      it "has correct domains for each space" do
        space1 = Space.make

        space2 = Space.make

        org1 = space1.organization
        org2 = space2.organization

        private_domain1 = PrivateDomain.make(owning_organization: org1)
        private_domain2 = PrivateDomain.make(owning_organization: org2)

        shared_domain = SharedDomain.make

        expect {
          @eager_loaded_spaces = Space.eager(:domains).where(id: [space1.id, space2.id]).limit(2).all
        }.to have_queried_db_times(/domains/i, 1)

        domains = [[private_domain1, shared_domain], [private_domain2, shared_domain]]

        expect {
          expect(@eager_loaded_spaces).to have(2).items
          expect(domains).to include(@eager_loaded_spaces[0].domains)
          expect(domains).to include(@eager_loaded_spaces[1].domains)
        }.to have_queried_db_times(//, 0)
      end

      it "passes in dataset to be loaded to eager_block option" do
        space = Space.make
        org = space.organization

        private_domain1 = PrivateDomain.make(owning_organization: org)
        private_domain2 = PrivateDomain.make(owning_organization: org)

        eager_block = proc { |ds| ds.where(id: private_domain1.id) }

        expect {
          @eager_loaded_space = Space.eager(domains: eager_block).where(id: space.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect(@eager_loaded_space.domains).to eql([private_domain1])
      end

      it "allow nested eager_load" do
        space = Space.make
        org = space.organization

        domain1 = PrivateDomain.make(owning_organization: org)
        domain2 = PrivateDomain.make(owning_organization: org)

        route1 = Route.make(domain: domain1, space: space)
        route2 = Route.make(domain: domain2, space: space)

        expect {
          @eager_loaded_space = Space.eager(domains: :routes).where(id: space.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_space.domains[0].routes).to eql([route1])
          expect(@eager_loaded_space.domains[1].routes).to eql([route2])
        }.to have_queried_db_times(//, 0)
      end
    end
  end

  describe "#having_developer" do
    it "returns only spaces with developers containing the specified user" do
      space1 = Space.make
      user = make_developer_for_space(space1)

      space2 = Space.make
      spaces = Space.having_developers(user).all

      expect(spaces).to include(space1)
      expect(spaces).to_not include(space2)
    end
  end
end
