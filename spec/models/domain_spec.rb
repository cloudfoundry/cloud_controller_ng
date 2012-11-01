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
          domain.update(:wildcard => true)
          space = Models::Space.make(
            :organization => domain.owning_organization,
          )
          space.add_domain(domain)
          Models::Route.make(
            :host => Sham.host,
            :domain => domain,
            :space => space,
          )
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

    describe "overlapping domains" do
      shared_examples "overlapping domains" do
        let(:domain_a) { Models::Domain.make(:name => name_a) }

        context "owned by the same org" do
          it "should be allowed" do
            domain_a.should be_valid
            Models::Domain.make(
              :name => name_b,
              :owning_organization => domain_a.owning_organization,
            ).should be_valid
          end
        end

        context "owned by different orgs" do
          it "should not be allowed" do
            domain_a.should be_valid
            expect {
              Models::Domain.make(:name => name_b)
            }.to raise_error(Sequel::ValidationFailed, /overlapping_domain/)
          end
        end
      end

      shared_examples "overlapping with system domain" do
        context "with system domain and non system domain" do

          it "should not be allowed" do
            system_domain = Models::Domain.new(
              :name => name_a,
              :wildcard => true,
              :owning_organization => nil
            ).save(:validate => false)

            expect {
              Models::Domain.make(:name => name_b)
            }.to raise_error(Sequel::ValidationFailed, /overlapping_domain/)
          end
        end
      end

      context "exact overlap" do
        let(:name_a) { Sham.domain }
        let(:name_b) { "foo.#{name_a}" }

        context "owned by different orgs" do
          it "should not be allowed" do
            domain_a = Models::Domain.make(:name => name_a)
            expect {
              Models::Domain.make(:name => domain_a.name)
            }.to raise_error(Sequel::ValidationFailed, /overlapping_domain/)
          end
        end

        include_examples "overlapping with system domain"
      end

      context "one level overlap" do
        let(:name_a) { Sham.domain }
        let(:name_b) { "foo.#{name_a}" }
        include_examples "overlapping domains"
        include_examples "overlapping with system domain"
      end

      context "multi level overlap" do
        let(:name_a) { "foo.bar.#{Sham.domain}" }
        let(:name_b) { "a.b.foo.bar.#{name_a}" }
        include_examples "overlapping domains"
        include_examples "overlapping with system domain"
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

      it "should associate with a shared domain" do
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

        it "should not remove the wildcard flag if routes are using it" do
          d = Models::Domain.make(:wildcard => true)
          s = Models::Space.make(:organization => d.owning_organization)
          s.add_domain(d)
          r = Models::Route.make(:host => Sham.host, :domain => d, :space => s)
          expect {
            d.update(:wildcard => false)
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should remove the wildcard flag if no routes are using it" do
          d = Models::Domain.make(:wildcard => true)
          s = Models::Space.make(:organization => d.owning_organization)
          s.add_domain(d)
          r = Models::Route.make(:host => nil, :domain => d, :space => s)
          d.update(:wildcard => false)
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

    context "shared_domains" do
      before do
        reset_database
      end

      context "with no domains" do
        it "should be empty" do
          Models::Domain.shared_domains.count.should == 0
        end
      end

      context "with a shared domain and a owned domain" do
        it "should return the shared domain" do
          shared = Models::Domain.find_or_create_shared_domain("a.com")
          Models::Domain.make
          Models::Domain.shared_domains.all.should == [shared]
        end
      end
    end
  end
end
