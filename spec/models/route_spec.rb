# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::Route do
  it_behaves_like "a CloudController model", {
    :required_attributes  => [:host, :domain, :organization],
    :unique_attributes    => [:host, :domain],
    :stripped_string_attributes => :host,
    :create_attribute => lambda { |name|
      @org ||= VCAP::CloudController::Models::Organization.make
      case name.to_sym
      when :organization_id
        @org.id
      when :domain_id
        VCAP::CloudController::Models::Domain.make(
          :owning_organization => @org
        ).id
      end
    },
    :create_attribute_reset => lambda { @org = nil },
    :many_to_one => {
      :domain => lambda { |route|
        VCAP::CloudController::Models::Domain.make(
          :owning_organization => route.organization
        )
      }
    },
    :many_to_zero_or_more => {
      :apps => lambda { |route|
        space = VCAP::CloudController::Models::Space.make(
          :organization => route.organization
        )
        space.add_domain(route.domain)
        VCAP::CloudController::Models::App.make(:space => space)
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
    end
  end

  describe "#fqdn" do
    it "should return the fqdn of for the route" do
      d = Models::Domain.make(:name => "foobar.com")
      r = Models::Route.make(:host => "www", :domain => d)
      r.fqdn.should == "www.foobar.com"
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
