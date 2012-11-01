# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Route do
    it_behaves_like "a CloudController model", {
      :required_attributes  => [:domain, :space],
      :db_required_attributes => [:domain, :space],
      :unique_attributes    => [:host, :domain],
      :stripped_string_attributes => :host,
      :create_attribute => lambda { |name|
        @space ||= Models::Space.make
        case name.to_sym
        when :space
          @space
        when :domain
          d = Models::Domain.make(
            :owning_organization => @space.organization,
            :wildcard => true
          )
          @space.add_domain(d)
          d
        when :host
          Sham.host
        end
      },
      :create_attribute_reset => lambda { @space = nil },
      :many_to_one => {
        :domain => lambda { |route|
          d = Models::Domain.make(
            :owning_organization => route.domain.organization
          )
          route.space.add_domain(d)
        }
      },
      :many_to_zero_or_more => {
        :apps => lambda { |route|
          Models::App.make(:space => route.space)
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
          let(:space) { Models::Space.make }
          let(:domain) do
            d = Models::Domain.make(
              :wildcard => true,
              :owning_organization => space.organization,
            )
            space.add_domain(d)
            d
          end

          it "should allow a nil host" do
            Models::Route.make(:space => space,
                               :domain => domain,
                               :host => nil).should be_valid
          end

          it "should not allow an empty host" do
            expect {
              Models::Route.make(:space => space,
                                 :domain => domain,
                                 :host => "")
            }.to raise_error(Sequel::ValidationFailed)
          end

          it "should not allow a blank host" do
            expect {
              Models::Route.make(:space => space,
                                 :domain => domain,
                                 :host => " ")
            }.to raise_error(Sequel::ValidationFailed)
          end
        end

        context "with a non-wild card domain" do
          let(:space) { Models::Space.make }
          let(:domain) do
            d = Models::Domain.make(
              :wildcard => false,
              :owning_organization => space.organization,
            )
            space.add_domain(d)
            d
          end

          it "should allow a nil host" do
            Models::Route.make(:space => space,
                               :domain => domain,
                               :host => nil).should be_valid
          end

          it "should not allow a valid host" do
            expect {
              Models::Route.make(:space => space,
                                 :domain => domain,
                                 :host => Sham.host)
            }.to raise_error(Sequel::ValidationFailed)
          end

          it "should not allow an empty host" do
            expect {
              Models::Route.make(:space => space,
                                 :domain => domain,
                                 :host => "")
            }.to raise_error(Sequel::ValidationFailed)
          end

          it "should not allow a blank host" do
            expect {
              Models::Route.make(:space => space,
                                 :domain => domain,
                                 :host => " ")
            }.to raise_error(Sequel::ValidationFailed)
          end
        end
      end
    end

    describe "#fqdn" do
      let(:space) { Models::Space.make }

      let(:domain) do
        d = Models::Domain.make(
          :wildcard => true,
          :owning_organization => space.organization
        )
        space.add_domain(d)
        d
      end

      context "for a non-nil host" do
        it "should return the fqdn for the route" do
          r = Models::Route.make(
            :host => "www",
            :domain => domain,
            :space => space,
          )
          r.fqdn.should == "www.#{domain.name}"
        end
      end

      context "for a nil host" do
        it "should return the fqdn for the route" do
          r = Models::Route.make(
            :host => nil,
            :domain => domain,
            :space => space,
          )
          r.fqdn.should == domain.name
        end
      end
    end

    describe "relations" do
      let(:org) { Models::Organization.make }
      let(:space_a) { Models::Space.make(:organization => org) }
      let(:domain_a) { Models::Domain.make(:owning_organization => org) }

      let(:space_b) { Models::Space.make(:organization => org) }
      let(:domain_b) { Models::Domain.make(:owning_organization => org) }

      before do
        Models::Domain.default_serving_domain_name = Sham.domain
      end

      after do
        Models::Domain.default_serving_domain_name = nil
      end

      it "should not allow creation of a route on a domain not on the space" do
        space_a.add_domain(domain_a)
        expect {
          Models::Route.make(:space => space_a, :domain => domain_b)
        }.should raise_error Sequel::ValidationFailed, /domain invalid_relation/
      end

      it "should not associate with apps from a different space" do
        space_a.add_domain(domain_a)
        space_b.add_domain(domain_a)

        route = Models::Route.make(:space => space_b, :domain => domain_a)
        app = Models::App.make(:space => space_a)
        expect {
          route.add_app(app)
        }.should raise_error Models::Route::InvalidAppRelation
      end

      it "should not allow creation of a nil host on a system domain" do
        expect {
          Models::Route.make(
            :host => nil, :space => space_a,
            :domain => Models::Domain.default_serving_domain
          )
        }.to raise_error Sequel::ValidationFailed
      end
    end
  end
end
