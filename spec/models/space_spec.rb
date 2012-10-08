# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Space do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :organization],
      :unique_attributes   => [:organization, :name],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :organization      => lambda { |space| Models::Organization.make }
      },
      :one_to_zero_or_more => {
        :apps              => lambda { |space| Models::App.make },
        :service_instances => lambda { |space| Models::ServiceInstance.make },
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

            lambda {
              space.send("add_#{perm.singularize}", user)
            }.should raise_error exception
          end
        end
      end

      ["developer", "manager", "auditor"].each do |perm|
        include_examples "bad app space permission", perm
      end

      it "should not associate an domain with a service from a different org" do
        lambda {
          domain = Models::Domain.make
          space.add_domain domain
        }.should raise_error Models::Space::InvalidDomainRelation
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
          space = Models::Organization.make
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
  end
end
