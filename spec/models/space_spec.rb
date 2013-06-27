# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Space do
    before(:all) do
      reset_database
    end

    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :organization],
      :unique_attributes   => [ [:organization, :name] ],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :organization      => {
          :delete_ok => true,
          :create_for => lambda { |space| Models::Organization.make }
        }
      },
      :one_to_zero_or_more => {
        :apps              => {
          :delete_ok => true,
          :create_for => lambda { |space| Models::App.make }
        },
        :service_instances => {
          :delete_ok => true,
          :create_for => lambda { |space| Models::ManagedServiceInstance.make }
        },
        :routes            => {
          :delete_ok => true,
          :create_for => lambda { |space| Models::Route.make(:space => space) }
        },
      },
      :many_to_zero_or_more => {
        :developers        => lambda { |space| make_user_for_space(space) },
        :managers          => lambda { |space| make_user_for_space(space) },
        :auditors          => lambda { |space| make_user_for_space(space) },
        :domains           => lambda { |space| make_domain_for_space(space) },
      }
    }

    context "bad relationships" do
      let(:space) { Models::Space.make }

      shared_examples "bad app space permission" do |perm|
        context perm do
          it "should not get associated with a #{perm.singularize} that isn't a member of the org" do
            exception = Models::Space.const_get("Invalid#{perm.camelize}Relation")
            wrong_org = Models::Organization.make
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
          domain = Models::Domain.make
          space.add_domain domain
        }.to raise_error Models::Space::InvalidDomainRelation
      end
    end

    describe "default domains" do
      context "with the default serving domain name set" do
        before do
          Models::Domain.default_serving_domain_name = "foo.com"
        end

        after do
          Models::Domain.default_serving_domain_name = nil
        end

        it "should be associated with the default serving domain" do
          space = Models::Space.make
          d = Models::Domain.default_serving_domain
          space.domains.map(&:guid) == [d.guid]
        end
      end
    end

    describe "data integrity" do
      it "should not make strings into integers" do
        space = Models::Space.make
        space.name.should be_kind_of(String)
        space.name = "1234"
        space.name.should be_kind_of(String)
        space.save
        space.refresh
        space.name.should be_kind_of(String)
      end
    end

    describe "#destroy" do
      subject(:space) { Models::Space.make }

      it "destroys all apps" do
        app = Models::App.make(:space => space)
        soft_deleted_app = Models::App.make(:space => space)
        soft_deleted_app.soft_delete

        expect {
          subject.destroy
        }.to change {
          Models::App.with_deleted.where(:id => [app.id, soft_deleted_app.id]).count
        }.from(2).to(0)
      end

      it "destroys all service instances" do
        service_instance = Models::ManagedServiceInstance.make(:space => space)

        expect {
          subject.destroy
        }.to change {
          Models::ManagedServiceInstance.where(:id => service_instance.id).count
        }.by(-1)
      end

      it "destroys all routes" do
        route = Models::Route.make(:space => space)
        expect {
          subject.destroy
        }.to change {
          Models::Route.where(:id => route.id).count
        }.by(-1)
      end

      it "nullifies any domains" do
        domain = Models::Domain.make(:owning_organization => space.organization)
        space.add_domain(domain)
        space.save
        expect { subject.destroy }.to change { domain.reload.spaces.count }.by(-1)
      end

      it "nullifies any default_users" do
        user = Models::User.make
        space.add_default_user(user)
        space.save
        expect { subject.destroy }.to change { user.reload.default_space }.from(space).to(nil)
      end
    end

    describe "filter deleted apps" do
      let(:space) { Models::Space.make }

      context "when deleted apps exist in the space" do
        it "should not return the deleted app" do
          deleted_app = Models::App.make(:space => space)
          deleted_app.soft_delete

          non_deleted_app = Models::App.make(:space => space)

          space.apps.should == [non_deleted_app]
        end
      end
    end
  end
end
