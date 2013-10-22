require "spec_helper"

module VCAP::CloudController
  describe Domain, type: :model do
    let(:domain) { Domain.make }

    it_behaves_like "a CloudController model", {
      required_attributes: [:name, :owning_organization, :wildcard],
      db_required_attributes: [:name],
      unique_attributes: :name,
      custom_attributes_for_uniqueness_tests: -> { {owning_organization: Organization.make} },
      stripped_string_attributes: :name,
      many_to_zero_or_one: {
        owning_organization: {
          delete_ok: true,
          create_for: ->(domain) {
            org = Organization.make
            domain.owning_organization = org
            domain.save
            org
          }
        }
      },
      many_to_many: {
        organizations: ->(domain) { Organization.make }
      },
      many_to_zero_or_more: {
        spaces: ->(domain) { Space.make(organization: domain.owning_organization) }
      },
      one_to_zero_or_more: {
        routes: {
          delete_ok: true,
          create_for: ->(domain) {
            domain.update(wildcard: true)
            space = Space.make(organization: domain.owning_organization)
            space.add_domain(domain)
            Route.make(domain: domain, space: space)
          }
        }
      }
    }

    describe "#as_summary_json" do
      context "with a system domain" do
        subject { Domain.new(:name => Sham.domain, :owning_organization => nil) }

        it "returns a hash containing the domain details" do
          subject.as_summary_json.should == {
            :guid => subject.guid,
            :name => subject.name,
            :owning_organization_guid => nil
          }
        end
      end

      context "with a custom domain" do
        let(:organization) { Organization.make }
        subject { Domain.new(:name => Sham.domain, :owning_organization => organization) }

        it "returns a hash containing the domain details" do
          subject.as_summary_json.should == {
            :guid => subject.guid,
            :name => subject.name,
            :owning_organization_guid => subject.owning_organization.guid
          }
        end
      end
    end

    describe "#intermidiate_domains" do
      context "name is nil" do
        it "should return nil" do
          Domain.intermediate_domains(nil).should == nil
        end
      end

      context "name is empty" do
        it "should return nil" do
          Domain.intermediate_domains("").should == nil
        end
      end

      context "name is not a valid domain" do
        Domain.intermediate_domains("bla").should == nil
      end

      context "valid domain" do
        it "should return an array of intermediate domains (minus the tld)" do
          Domain.intermediate_domains("a.b.c.d.com").should ==
            [ "com", "d.com", "c.d.com", "b.c.d.com", "a.b.c.d.com"]
        end
      end
    end

    describe "creating shared domains" do
      context "as an admin" do
        before do
          admin = User.make(:admin => true)
          SecurityContext.set(admin)
        end

        after do
          SecurityContext.clear
        end

        it "should allow the creation of a shared domain" do
          d = Domain.new(:name => "shared.com")
          d.owning_organization.should be_nil
        end
      end

      context "as a standard user" do
        before do
          user = User.make(:admin => false)
          SecurityContext.set(user)
        end

        after do
          SecurityContext.clear
        end

        it "should not allow the creation of a shared domain" do
          expect {
            Domain.create(:name => "shared.com")
          }.to raise_error Sequel::ValidationFailed, /organization presence/
        end
      end
    end

    describe "overlapping domains" do
      shared_examples "overlapping domains" do
        let(:domain_a) { Domain.make(:name => name_a) }

        context "owned by the same org" do
          it "should be allowed" do
            domain_a.should be_valid
            Domain.make(
              :name => name_b,
              :owning_organization => domain_a.owning_organization,
            ).should be_valid
          end
        end

        context "owned by different orgs" do
          it "should not be allowed" do
            domain_a.should be_valid
            expect {
              Domain.make(:name => name_b)
            }.to raise_error(Sequel::ValidationFailed, /overlapping_domain/)
          end
        end
      end

      shared_examples "overlapping with system domain" do
        context "with system domain and non system domain" do

          it "should not be allowed" do
            system_domain = Domain.new(
              :name => name_a,
              :wildcard => true,
              :owning_organization => nil
            ).save(:validate => false)

            expect {
              Domain.make(:name => name_b)
            }.to raise_error(Sequel::ValidationFailed, /overlapping_domain/)
          end
        end
      end

      context "exact overlap" do
        let(:name_a) { Sham.domain }
        let(:name_b) { "foo.#{name_a}" }

        context "owned by different orgs" do
          it "should not be allowed" do
            domain_a = Domain.make(:name => name_a)
            expect {
              Domain.make(:name => domain_a.name)
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
      context "custom domains" do
        let(:org) { Organization.make }

        let(:domain) {
          Domain.make(:owning_organization => org)
        }

        let(:space) { Space.make }

        it "should not associate with an app space on a different org" do
          expect {
            domain.add_space(space)
          }.to raise_error Domain::InvalidSpaceRelation
        end

        it "should not associate with orgs other than the owning org" do
          expect {
            domain.add_organization(Organization.make)
          }.to raise_error Domain::InvalidOrganizationRelation
        end

        it "should auto-associate with the owning org" do
          domain.should be_valid
          org.domains.should include(domain)
        end
      end

      context "shared domains" do
        let(:shared_domain) do
          Domain.find_or_create_shared_domain(Sham.domain)
        end

        it "should auto-associate with a new org" do
          shared_domain.should be_valid
          org = Organization.make
          org.domains.should include(shared_domain)
        end

        it "should not auto-associate with an existing org" do
          org = Organization.make
          new_shared_domain = Domain.find_or_create_shared_domain(Sham.domain)
          org.domains.should_not include(new_shared_domain)
        end

        it "should manually associate with an org" do
          # while this seems like it shouldn't need to be tested, at some point
          # in the past, this pattern had failed.
          shared_domain.add_organization(Organization.make)
          shared_domain.should be_valid
          shared_domain.save
          shared_domain.should be_valid
        end
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
          d = Domain.new(
            :owning_organization => domain.owning_organization,
            :name => domain.name.upcase)
            d.should_not be_valid
        end

        it "should not remove the wildcard flag if routes are using it" do
          d = Domain.make(:wildcard => true)
          s = Space.make(:organization => d.owning_organization)
          s.add_domain(d)
          r = Route.make(:host => Sham.host, :domain => d, :space => s)
          expect {
            d.update(:wildcard => false)
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should remove the wildcard flag if no routes are using it" do
          d = Domain.make(:wildcard => true)
          s = Space.make(:organization => d.owning_organization)
          s.add_domain(d)
          r = Route.make(:host => "", :domain => d, :space => s)
          d.update(:wildcard => false)
        end
      end
    end

    describe "default_serving_domain" do
      context "with the default serving domain name set" do
        before do
          Domain.default_serving_domain_name = "foo.com"
        end

        after do
          Domain.default_serving_domain_name = nil
        end

        it "should return the default serving domain" do
          d = Domain.default_serving_domain
          d.name.should == "foo.com"
        end
      end

      context "without the default seving domain name set" do
        it "should return nil" do
          d = Domain.default_serving_domain
          d.should be_nil
        end
      end
    end

    context "shared_domains" do
      context "with no domains" do
        it "should be empty" do
          Domain.shared_domains.count.should == 0
        end
      end

      context "with a shared domain and a owned domain" do
        it "should return the shared domain" do
          shared = Domain.find_or_create_shared_domain("a.com")
          Domain.make
          Domain.shared_domains.all.should == [shared]
        end
      end
    end

    describe "#destroy" do
      subject { domain.destroy(savepoint: true) }
      let(:space) do
        Space.make(:organization => domain.owning_organization).tap do |space|
          space.add_domain(domain)
          space.save
        end
      end

      it "should destroy the routes" do
        route = Route.make(:domain => domain, :space => space)
        expect { subject }.to change { Route.where(:id => route.id).count }.by(-1)
      end

      it "nullifies the organization" do
        organization = domain.owning_organization
        expect { subject }.to change { organization.reload.domains.count }.by(-1)
      end

      it "nullifies the space" do
        expect { subject }.to change { space.reload.domains.count }.by(-1)
      end
    end
  end
end
