# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::Organization do
    before(:all) { reset_database }

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

    describe "validation" do
      let!(:org) do
        Models::Organization.make(can_access_non_public_plans: false)
      end

      it "allows cf admins to change 'can_access_non_public_plans'" do
        SecurityContext.stub(:current_user_is_admin? => true)
        expect {
          org.update(:can_access_non_public_plans => true)
        }.to_not raise_error Sequel::ValidationFailed, /can_access_non_public_plans/
      end

      it "does not allow non-admins to change 'can_access_non_public_plans'" do
        SecurityContext.stub(:current_user_is_admin? => false)
        expect {
          org.update(:can_access_non_public_plans => true)
        }.to raise_error Sequel::ValidationFailed, /can_access_non_public_plans/
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
          org = Models::Organization.make
          d = Models::Domain.default_serving_domain
          org.domains.map(&:guid) == [d.guid]
        end
      end
    end

    describe "default access control" do
      it "cannot access non-public service plans" do
        Models::Organization.make.can_access_non_public_plans.should eq(false)
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
                :package_hash => "abc",
                :package_state => "STAGED",
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

      let(:unlimited_quota) do
        Models::QuotaDefinition.make(:total_services => -1,
          :non_basic_services_allowed => true)
      end

      let(:free_plan) { Models::ServicePlan.make(:free => true)}

      describe "#service_instance_quota_remaining?" do
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

        it "returns true when the limit is -1 (unlimited)" do
          org = Models::Organization.make(:quota_definition => unlimited_quota)
          space = Models::Space.make(:organization => org)
          org.service_instance_quota_remaining?.should be_true
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
        Models::QuotaDefinition.make(:memory_limit => 500)
      end

      it "should return the memory available when no apps are running" do
        org = Models::Organization.make(:quota_definition => quota)

        org.memory_remaining.should == 500
      end

      it "should return the memory remaining when apps are consuming memory" do
        org = Models::Organization.make(:quota_definition => quota)
        space = Models::Space.make(:organization => org)
        Models::App.make(:space => space,
                         :memory => 200,
                         :instances => 2)
        Models::App.make(:space => space,
                         :memory => 50,
                         :instances => 1)

        org.memory_remaining.should == 50
      end
    end

    describe "#destroy" do
      let(:org) { Models::Organization.make }
      let(:space) { Models::Space.make(:organization => org) }

      subject { org.reload.destroy }

      it "destroys all apps" do
        app = Models::App.make(:space => space)
        expect { subject }.to change { Models::App[:id => app.id] }.from(app).to(nil)
      end

      it "destroys all spaces" do
        expect { subject }.to change { Models::Space[:id => space.id] }.from(space).to(nil)
      end

      it "destroys all service instances" do
        service_instance = Models::ServiceInstance.make(:space => space)
        expect { subject }.to change { Models::ServiceInstance[:id => service_instance.id] }.from(service_instance).to(nil)
      end

      it "destroys the owned domain" do
        domain = Models::Domain.make(:owning_organization => org)
        expect { subject }.to change { Models::Domain[:id => domain.id] }.from(domain).to(nil)
      end

      it "nullify domains" do
        SecurityContext.set(Models::User.make(:admin => true))
        domain = Models::Domain.make(:owning_organization => nil)
        domain.add_organization(org)
        domain.save
        expect { subject }.to change { domain.reload.organizations.count }.by(-1)
      end
    end

    describe "#trial_db_allocated?" do
      let(:org) { Models::Organization.make }
      let(:space) { Models::Space.make :organization => org }
      let(:trial_db_guid) { Models::ServicePlan.trial_db_guid }
      subject { org.trial_db_allocated? }

      context "when a trial db instance has not been allocated" do
        it "retruns false" do
          expect(subject).to eq false
        end
      end

      context "when a trial db instance has been allocated" do
        let(:service_plan) { Models::ServicePlan.make :unique_id => trial_db_guid}
        it "returns true" do
          Models::ServiceInstance.make(:space => space, :service_plan => service_plan)
          expect(subject).to eq true
        end
      end
    end

    describe "#service_plan_quota_remaining?" do
      let(:org) do
        Models::Organization.make :quota_definition => quota
      end

      let(:trial_db_guid) { Models::ServicePlan.trial_db_guid }

      let!(:space) do
        Models::Space.make(:organization => org)
      end

      subject { org.check_quota?(service_plan) }

      context "when the service plan requested is the trial db" do
        let(:service_plan) do
            Models::ServicePlan.find(:unique_id => trial_db_guid) ||
              Models::ServicePlan.make(:unique_id => trial_db_guid)
        end

        context "and the org's quota definition is paid" do
          context "and the number of total instances does not exceed the quota restriction" do
            let(:quota) do
              Models::QuotaDefinition.make(:total_services => 1)
            end

            it "return an empty hash" do
              expect(subject).to be_empty
            end
          end

          context "and the number of total instances exceeds than the quota restriction" do
            let(:quota) do
              Models::QuotaDefinition.make(:total_services => 0)
            end

            it "returns a :paid_quota_exceeded error on the org" do
              expect(subject).to eq({:type => :org, :name => :paid_quota_exceeded })
            end
          end

        end

        context "and the org's quota definition is unpaid" do
          let(:quota) do
            Models::QuotaDefinition.make(:non_basic_services_allowed => false)
          end

          it "returns a :paid_services_not_allowed error on the service plan" do
            expect(subject).to eq({:type => :service_plan, :name => :paid_services_not_allowed })
          end
        end

        context "and the org's quota definition is trial" do
          let(:quota) do
            Models::QuotaDefinition.find(:non_basic_services_allowed => false, :trial_db_allowed => true)
          end

          it "returns no error if the org has not allocated a trial db" do
            expect(subject).to be_empty
          end

          it "returns a :trial_quota_exceeded error if the org has allocated a trial db" do
            Models::Organization.any_instance.stub(:trial_db_allocated?).and_return(true)
            expect(subject).to eq({ :type => :org, :name => :trial_quota_exceeded })
          end

        end
      end

      context "when the service plan requested is not trial db" do
        context "and the service plan is free" do
          let(:service_plan) { Models::ServicePlan.make :free => true }

          context "and the number of total instances is less than the quota restriction" do
            let(:quota) { Models::QuotaDefinition.make :total_services => 1 }
            it "returns no error" do
              expect(subject).to be_empty
            end
          end

          context "and the number of total instances is greater than the quota restriction" do
            let(:quota) do
              Models::QuotaDefinition.make(:total_services => 0, :non_basic_services_allowed => false)
            end

            it "returns :free_quota_exceeded for the org" do
              expect(subject).to eq({ :type => :org, :name => :free_quota_exceeded })
            end
          end
        end

        context "and the quota is paid" do
          let(:service_plan) { Models::ServicePlan.make }
          context "and the number of total instances is less than the quota restriction" do
            let(:quota) do
              Models::QuotaDefinition.make(:total_services => 1, :non_basic_services_allowed => true)
            end

            it "returns no error" do
              expect(subject).to be_empty
            end
          end

          context "and the number of total instances is greater than the quota restriction" do
            let(:quota) do
              Models::QuotaDefinition.make(:total_services => 0, :non_basic_services_allowed => true)
            end

            it "returns :paid_quota_exceeded error for the org" do
              expect(subject).to eq({ :type => :org, :name => :paid_quota_exceeded })
            end
          end
        end

        context "and the quota is unpaid and the service plan is not free" do
          let(:quota) do
            Models::QuotaDefinition.make(:total_services => 1, :non_basic_services_allowed => false)
          end
          let(:service_plan) { Models::ServicePlan.make :free => false }
          it "returns a :paid_services_not_allowed error for the service plan" do
            expect(subject).to eq({ :type => :service_plan, :name => :paid_services_not_allowed })
          end
        end
      end
    end

    describe "filter deleted apps" do
      let(:org) { Models::Organization.make }
      let(:space) { Models::Space.make(:organization => org) }

      context "when deleted apps exist in the organization" do
        it "should not return the deleted apps" do
          deleted_app = Models::App.make(:space => space)
          deleted_app.soft_delete

          non_deleted_app = Models::App.make(:space => space)

          org.apps.should == [non_deleted_app]
        end
      end
    end
  end
end
