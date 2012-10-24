# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Route do
    it_behaves_like "a CloudController model", {
      :required_attributes  => [:domain, :organization],
      :db_required_attributes => [:domain, :organization],
      :unique_attributes    => [:host, :domain],
      :stripped_string_attributes => :host,
      :create_attribute => lambda { |name|
        @org ||= Models::Organization.make
        case name.to_sym
        when :organization
          @org
        when :domain
          Models::Domain.make(
            :owning_organization => @org,
            :wildcard => true
          )
        when :host
          Sham.host
        end
      },
      :create_attribute_reset => lambda { @org = nil },
      :many_to_one => {
        :domain => lambda { |route|
          Models::Domain.make(
            :owning_organization => route.organization
          )
        }
      },
      :many_to_zero_or_more => {
        :apps => lambda { |route|
          space = Models::Space.make(
            :organization => route.organization
          )
          space.add_domain(route.domain)
          Models::App.make(:space => space)
        }
      }
    }

    describe "validations" do
      let(:route) { Models::Route.make }

      describe "host" do
        it "should not allow . in the host name" do
          route.host = "a.b"
          route.should_not be_valid
        end

        it "should not allow / in the host name" do
          route.host = "a/b"
          route.should_not be_valid
        end

        context "with a wildcard domain" do
          let(:domain) { Models::Domain.make(:wildcard => true) }

          it "should allow a nil host" do
            Models::Route.make(:organization => domain.owning_organization,
                               :domain => domain,
                               :host => nil).should be_valid
          end

          it "should not allow an empty host" do
            expect {
              Models::Route.make(:organization => domain.owning_organization,
                                 :domain => domain,
                                 :host => "")
            }.to raise_error(Sequel::ValidationFailed)
          end

          it "should not allow a blank host" do
            expect {
              Models::Route.make(:organization => domain.owning_organization,
                                 :domain => domain,
                                 :host => " ")
            }.to raise_error(Sequel::ValidationFailed)
          end
        end

        context "with a non-wild card domain" do
          let(:domain) { Models::Domain.make(:wildcard => false) }

          it "should allow a nil host" do
            Models::Route.make(:organization => domain.owning_organization,
                               :domain => domain,
                               :host => nil).should be_valid
          end

          it "should not allow a valid host" do
            expect {
              Models::Route.make(:organization => domain.owning_organization,
                                 :domain => domain,
                                 :host => Sham.host)
            }.to raise_error(Sequel::ValidationFailed)
          end

          it "should not allow an empty host" do
            expect {
              Models::Route.make(:organization => domain.owning_organization,
                                 :domain => domain,
                                 :host => "")
            }.to raise_error(Sequel::ValidationFailed)
          end

          it "should not allow a blank host" do
            expect {
              Models::Route.make(:organization => domain.owning_organization,
                                 :domain => domain,
                                 :host => " ")
            }.to raise_error(Sequel::ValidationFailed)
          end
        end
      end
    end

    describe "#fqdn" do
      context "for a non-nil host" do
        it "should return the fqdn of for the route" do
          d = Models::Domain.make(:wildcard => true)
          r = Models::Route.make(:host => "www", :domain => d)
          r.fqdn.should == "www.#{d.name}"
        end
      end

      context "for a nil host" do
        d = Models::Domain.make(:wildcard => true)
        r = Models::Route.make(:host => nil, :domain => d)
        r.fqdn.should == d.name
      end
    end

    describe "relations" do
      let(:org_a) { Models::Organization.make }
      let(:space_a) { Models::Space.make(:organization => org_a) }
      let(:domain_a) { Models::Domain.make(:owning_organization => org_a) }

      let(:org_b) { Models::Organization.make }
      let(:space_b) { Models::Space.make(:organization => org_b) }
      let(:domain_b) { Models::Domain.make(:owning_organization => org_b) }

      it "should not allow creation of a route on a domain from another org" do
        expect {
          Models::Route.make(:organization => org_a, :domain => domain_b)
        }.should raise_error Sequel::ValidationFailed, /domain invalid_relation/
      end

      it "should not associate with apps where the domain isn't on the space" do
        route = Models::Route.make(:organization => org_a, :domain => domain_a)
        app = Models::App.make(:space => space_a)
        expect {
          route.add_app(app)
        }.should raise_error Models::Route::InvalidDomainRelation
      end
    end
  end
end
