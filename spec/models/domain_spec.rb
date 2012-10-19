# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Domain do
    let(:domain) { Models::Domain.make }

    it_behaves_like "a CloudController model", {
      :required_attributes          => [:name, :owning_organization, :wildcard],
      :db_required_attributes       => [:name],
      :unique_attributes            => :name,
      :stripped_string_attributes   => :name,
      :many_to_zero_or_one => {
        :owning_organization => lambda { |domain| Models::Organization.make }
      },
      :many_to_many => {
        :organizations => lambda {
          |domain| Models::Organization.make
        }
      },
      :many_to_zero_or_more => {
        :spaces => lambda { |domain|
          Models::Space.make(:organization => domain.owning_organization)
        }
      },
      :one_to_zero_or_more => {
        :routes => lambda { |domain|
          Models::Route.make(:domain => domain)
        }
      }
    }

    describe "#intermidiate_domains" do
      context "name is nil" do
        it "should return nil" do
          Models::Domain.intermediate_domains(nil).should == nil
        end
      end

      context "name is empty" do
        it "should return nil" do
          Models::Domain.intermediate_domains("").should == nil
        end
      end

      context "name is not a valid domain" do
        Models::Domain.intermediate_domains("bla").should == nil
      end

      context "valid domain" do
        it "should return an array of intermediate domains (minus the tld)" do
          Models::Domain.intermediate_domains("a.b.c.d.com").should ==
            [ "com", "d.com", "c.d.com", "b.c.d.com", "a.b.c.d.com"]
        end
      end
    end

    describe "creating shared domains" do
      context "as an admin" do
        before do
          admin = Models::User.make(:admin => true)
          SecurityContext.set(admin)
        end

        after do
          SecurityContext.clear
        end

        it "should allow the creation of a shared domain" do
          d = Models::Domain.new(:name => "shared.com")
          d.owning_organization.should be_nil
        end
      end

      context "as a standard user" do
        before do
          user = Models::User.make(:admin => false)
          SecurityContext.set(user)
        end

        after do
          SecurityContext.clear
        end

        it "should not allow the creation of a shared domain" do
          expect {
            Models::Domain.create(:name => "shared.com")
          }.should raise_error Sequel::ValidationFailed, /organization presence/
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

        it "should accept a three level domain" do
          domain.name = "a.b.com"
          domain.should be_valid
        end

        it "should accept a four level domain" do
          domain.name = "a.b.c.com"
          domain.should be_valid
        end

        it "should accept a domain with a 2 char top level domain" do
          domain.name = "b.c.au"
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

        it "should not allow a domain with a leading dot" do
          domain.name = ".b.c.com"
          domain.should_not be_valid
        end

        it "should not allow a domain with a single char top level domain" do
          domain.name = "b.c.d"
          domain.should_not be_valid
        end

        it "should not allow a domain with a 6 char top level domain" do
          domain.name = "b.c.abcefg"
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
end
