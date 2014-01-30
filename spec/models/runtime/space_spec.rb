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

    describe "validations" do
      context "name" do
        let(:space) { Space.make }

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
      let(:space) { Space.make }

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
      let(:space) { Space.make() }

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
          expect { space.add_domain(private_domain) }.to raise_error(Space::UnauthorizedAccessToPrivateDomain)
        end
      end
    end
  end
end
