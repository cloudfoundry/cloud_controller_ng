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
        :domains           => lambda { |space| make_domain_for_space(space) },
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

      it "should not associate an domain with a service from a different org" do
        expect {
          domain = Domain.make
          space.add_domain domain
        }.to raise_error Space::InvalidDomainRelation
      end
    end

    describe "default domains" do
      context "with the default serving domain name set" do
        before do
          Domain.default_serving_domain_name = "foo.com"
        end

        after do
          Domain.default_serving_domain_name = nil
        end

        it "should be associated with the default serving domain" do
          space = Space.make
          d = Domain.default_serving_domain
          space.domains.map(&:guid) == [d.guid]
        end
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

      it "destroys all apps" do
        app = AppFactory.make(:space => space)
        soft_deleted_app = AppFactory.make(:space => space)
        soft_deleted_app.soft_delete

        expect {
          subject.destroy(savepoint: true)
        }.to change {
          App.with_deleted.where(:id => [app.id, soft_deleted_app.id]).count
        }.from(2).to(0)
      end

      it "destroys all service instances" do
        service_instance = ManagedServiceInstance.make(:space => space)

        expect {
          subject.destroy(savepoint: true)
        }.to change {
          ManagedServiceInstance.where(:id => service_instance.id).count
        }.by(-1)
      end

      it "destroys all routes" do
        route = Route.make(:space => space)
        expect {
          subject.destroy(savepoint: true)
        }.to change {
          Route.where(:id => route.id).count
        }.by(-1)
      end

      it "nullifies any domains" do
        domain = Domain.make(:owning_organization => space.organization)
        space.add_domain(domain)
        space.save
        expect { subject.destroy(savepoint: true) }.to change { domain.reload.spaces.count }.by(-1)
      end

      it "nullifies any default_users" do
        user = User.make
        space.add_default_user(user)
        space.save
        expect { subject.destroy(savepoint: true) }.to change { user.reload.default_space }.from(space).to(nil)
      end

      it "destroys all events" do
        event = Event.make(:space => space)

        expect {
          subject.destroy(savepoint: true)
        }.to_not change {
          Event.where(:id => [event.id]).count
        }

        Event.find(:id => event.id).space.should be_a(DeletedSpace)
      end
    end

    describe "filter deleted apps" do
      let(:space) { Space.make }

      context "when deleted apps exist in the space" do
        it "should not return the deleted app" do
          deleted_app = AppFactory.make(:space => space)
          deleted_app.soft_delete

          non_deleted_app = AppFactory.make(:space => space)

          space.apps.should == [non_deleted_app]
        end
      end
    end
  end
end
