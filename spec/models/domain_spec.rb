# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::Domain do
  let(:domain) { Models::Domain.make }

  it_behaves_like "a CloudController model", {
    :required_attributes          => [:name, :owning_organization],
    :db_required_attributes       => [:name],
    :unique_attributes            => :name,
    :stripped_string_attributes   => :name,
    :many_to_zero_or_one => {
      :owning_organization => lambda { |domain| VCAP::CloudController::Models::Organization.make }
    },
    :many_to_many => {
      :organizations => lambda {
        |domain| VCAP::CloudController::Models::Organization.make
      }
    },
    :many_to_zero_or_more => {
      :spaces => lambda { |domain|
        VCAP::CloudController::Models::Space.make(:organization => domain.owning_organization)
      }
    },
    :one_to_zero_or_more => {
      :routes => lambda { |domain|
        VCAP::CloudController::Models::Route.make(:domain => domain)
      }
    }
  }

  describe "creating shared domains" do
    context "as an admin" do
      before do
        admin = Models::User.make(:admin => true)
        VCAP::CloudController::SecurityContext.current_user = admin
      end

      after do
        VCAP::CloudController::SecurityContext.current_user = nil
      end

      it "should allow the creation of a shared domain" do
        d = Models::Domain.new(:name => "shared.com")
        d.owning_organization.should be_nil
      end
    end

    context "as a standard user" do
      before do
        user = Models::User.make(:admin => false)
        VCAP::CloudController::SecurityContext.current_user = user
      end

      after do
        VCAP::CloudController::SecurityContext.current_user = nil
      end

      it "should not allow the creation of a shared domain" do
        expect {
          Models::Domain.create(:name => "shared.com")
        }.should raise_error Sequel::ValidationFailed, /organization presence/
      end
    end
  end

  describe "conversions" do
    describe "name" do
      it "should downcase the name" do
        d = Models::Domain.create(
          :owning_organization => domain.owning_organization,
          :name => "ABC.COM")
        d.name.should == "abc.com"
      end
    end
  end

  context "relationships" do
    let(:domain) { Models::Domain.make(
      :owning_organization => Models::Organization.make)
    }
    let(:space) { Models::Space.make }

    it "should not associate with an app space on a different org" do
      lambda {
        domain.add_space(space)
      }.should raise_error Models::Domain::InvalidSpaceRelation
    end

    it "should not associate with orgs other than the owning org" do
      lambda {
        domain.add_organization(Models::Organization.make)
      }.should raise_error Models::Domain::InvalidOrganizationRelation
    end

    it "should associate with a shared org" do
      shared_domain = Models::Domain.new(:name => "abc.com",
                                         :owning_organization => nil)
      shared_domain.save(:validate => false)
      shared_domain.add_organization(Models::Organization.make)
      shared_domain.should be_valid
      shared_domain.save
      shared_domain.should be_valid
    end
  end

  describe "validations" do
    describe "name" do
      it "should accept a two level domain" do
        domain.name = "a.com"
        domain.should be_valid
      end

      it "should not allow a one level domain" do
        domain.name = "com"
        domain.should_not be_valid
      end

      it "should not allow a domain without a host" do
        domain.name = ".com"
        domain.should_not be_valid
      end

      it "should not allow a domain with a trailing dot" do
        domain.name = "a.com."
        domain.should_not be_valid
      end

      it "should not allow a three level domain TEMPORARY!" do
        domain.name = "a.b.com"
        domain.should_not be_valid
      end

      it "should perform case insensitive uniqueness" do
        d = Models::Domain.new(
          :owning_organization => domain.owning_organization,
          :name => domain.name.upcase)
        d.should_not be_valid
      end
    end
  end

  describe "default_serving_domain" do
    context "with the default serving domain name set" do
      before do
        Models::Domain.default_serving_domain_name = "foo.com"
      end

      after do
        Models::Domain.default_serving_domain_name = nil
      end

      it "should return the default serving domain" do
        d = Models::Domain.default_serving_domain
        d.name.should == "foo.com"
      end
    end

    context "without the default seving domain name set" do
      it "should return nil" do
        d = Models::Domain.default_serving_domain
        d.should be_nil
      end
    end
  end
end
