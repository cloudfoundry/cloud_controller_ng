# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Organization do
    before(:all) do
      reset_database
    end

    it_behaves_like "a CloudController model", {
      :required_attributes          => :name,
      :unique_attributes            => :name,
      :stripped_string_attributes   => :name,
      :many_to_zero_or_more => {
        :users      => lambda { |org| Models::User.make },
        :managers   => lambda { |org| Models::User.make },
        :billing_managers => lambda { |org| Models::User.make },
        :auditors   => lambda { |org| Models::User.make },
      },
      :one_to_zero_or_more => {
        :spaces  => lambda { |org| Models::Space.make },
        :domains => lambda { |org|
          Models::Domain.make(:owning_organization => org)
        }
      }
    }

    describe "default domains" do
      context "with the default serving domain name set" do
        before do
          Models::Domain.default_serving_domain_name = "foo.com"
        end

        after do
          Models::Domain.default_serving_domain_name = nil
        end

        it "should be associated with the default serving domain" do
          org = Models::Organization.make
          d = Models::Domain.default_serving_domain
          org.domains.map(&:guid) == [d.guid]
        end
      end
    end

    context "with multiple shared domains" do
      it "should be associated with the shared domains that exist at creation time" do
        org = Models::Organization.make
        shared_count = Models::Domain.shared_domains.count
        org.domains.count.should == shared_count
        d = Models::Domain.find_or_create_shared_domain(Sham.domain)
        d.should be_valid
        org.domains.count.should == shared_count
      end
    end

    describe "billing" do
      it "should not be enabled for billing when first created" do
        Models::Organization.make.billing_enabled.should == false
      end

      context "enabling billing" do
        let (:org) do
          o = Models::Organization.make
          2.times do
            space = Models::Space.make(
              :organization => o,
            )
            2.times do
              app = Models::App.make(
                :space => space,
                :state => "STARTED",
              )
              Models::App.make(
                :space => space,
                :state => "STOPPED",
              )
              service_instance = Models::ServiceInstance.make(
                :space => space,
              )
            end
          end
          o
        end

        it "should call OrganizationStartEvent.create_from_org" do
          Models::OrganizationStartEvent.should_receive(:create_from_org)
          org.billing_enabled = true
          org.save(:validate => false)
        end

        it "should emit start events for running apps" do
          ds = Models::AppStartEvent.filter(
            :organization_guid => org.guid,
          )
          # FIXME: don't skip validation
          org.billing_enabled = true
          org.save(:validate => false)
          ds.count.should == 4
        end

        it "should emit create events for provisioned services" do
          ds = Models::ServiceCreateEvent.filter(
            :organization_guid => org.guid,
          )
          # FIXME: don't skip validation
          org.billing_enabled = true
          org.save(:validate => false)
          ds.count.should == 4
        end
      end
    end

    context "service instances quota" do
      let(:free_quota) do
        Models::QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => false)
      end
      let(:paid_quota) do
        Models::QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => true)
      end
      let(:free_plan) { Models::ServicePlan.make(:free => true)}

      describe "#service_instance_quota_remaining" do
        it "should return true when quota is not reached" do
          org = Models::Organization.make(:quota_definition => free_quota)
          space = Models::Space.make(:organization => org)
          org.service_instance_quota_remaining?.should be_true
        end

        it "should return false when quota is reached" do
          org = Models::Organization.make(:quota_definition => free_quota)
          space = Models::Space.make(:organization => org)
          org.service_instance_quota_remaining?.should be_true
          Models::ServiceInstance.make(:space => space,
                                       :service_plan => free_plan).
            save(:validate => false)
          org.refresh
          org.service_instance_quota_remaining?.should be_false
        end
      end

      describe "#paid_services_allowed" do
        it "should return true when org has paid quota" do
          org = Models::Organization.make(:quota_definition => paid_quota)
          org.paid_services_allowed?.should be_true
        end

        it "should return false when org has free quota" do
          org = Models::Organization.make(:quota_definition => free_quota)
          org.paid_services_allowed?.should be_false
        end
      end
    end

    context "memory quota" do
      let(:quota) do
        Models::QuotaDefinition.make(:free_memory_limit => 500,
                                     :paid_memory_limit => 500)
      end

      it "should return the memory available when no apps are running" do
        org = Models::Organization.make(:quota_definition => quota)

        org.free_memory_remaining.should == 500
        org.paid_memory_remaining.should == 500
      end

      it "should return the memory remaining when apps are consuming memory" do
        org = Models::Organization.make(:quota_definition => quota)
        space = Models::Space.make(:organization => org)
        Models::App.make(:space => space,
                         :production => false,
                         :memory => 200,
                         :instances => 2)
        Models::App.make(:space => space,
                         :production => true,
                         :memory => 100,
                         :instances => 1)

        org.free_memory_remaining.should == 100
        org.paid_memory_remaining.should == 400
      end
    end
  end
end
