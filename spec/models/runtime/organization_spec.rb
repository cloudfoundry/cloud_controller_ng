require "spec_helper"

module VCAP::CloudController
  describe Organization, type: :model do
    it_behaves_like "a CloudController model", {
      :required_attributes          => :name,
      :unique_attributes            => :name,
      :custom_attributes_for_uniqueness_tests => ->{ {quota_definition: QuotaDefinition.make} },
      :stripped_string_attributes   => :name,
      :many_to_zero_or_more => {
        :users      => lambda { |org| User.make },
        :managers   => lambda { |org| User.make },
        :billing_managers => lambda { |org| User.make },
        :auditors   => lambda { |org| User.make },
      },
      :one_to_zero_or_more => {
        :spaces  => lambda { |org| Space.make },
        :domains => lambda { |org|
          Domain.make(:owning_organization => org)
        }
      }
    }

    describe "validations" do
      context "name" do
        let(:org) { Organization.make }

        it "shoud allow word characters, spaces, parentheses and !&?\'\"" do
          org.name = "A -_- word 2!?()\'\"&"
          expect{
            org.save
          }.to_not raise_error
        end

        it "should not allow backslash characters" do
          org.name = "a\\word"
          expect{
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should not allow newline characters" do
          org.name = "one\ntwo"
          expect{
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it "should not allow escape characters" do
          org.name = "a\e word"
          expect{
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end
    end

    describe "default domains" do
      context "with the default serving domain name set" do
        before do
          Domain.default_serving_domain_name = "foo.com"
        end

        after do
          Domain.default_serving_domain_name = nil
        end

        it "should be associated with the default serving domain" do
          org = Organization.make
          d = Domain.default_serving_domain
          org.domains.map(&:guid) == [d.guid]
        end
      end
    end

    context "with multiple shared domains" do
      it "should be associated with the shared domains that exist at creation time" do
        org = Organization.make
        shared_count = Domain.shared_domains.count
        org.domains.count.should == shared_count
        d = Domain.find_or_create_shared_domain(Sham.domain)
        d.should be_valid
        org.domains.count.should == shared_count
      end
    end

    describe "billing" do
      it "should not be enabled for billing when first created" do
        Organization.make.billing_enabled.should == false
      end

      context "enabling billing" do
        let (:org) do
          o = Organization.make
          2.times do
            space = Space.make(
              :organization => o,
            )
            2.times do
              app = AppFactory.make(
                :space => space,
                :state => "STARTED",
                :package_hash => "abc",
                :package_state => "STAGED",
              )
              AppFactory.make(
                :space => space,
                :state => "STOPPED",
              )
              service_instance = ManagedServiceInstance.make(
                :space => space,
              )
            end
          end
          o
        end

        it "should call OrganizationStartEvent.create_from_org" do
          OrganizationStartEvent.should_receive(:create_from_org)
          org.billing_enabled = true
          org.save(:validate => false)
        end

        it "should emit start events for running apps" do
          ds = AppStartEvent.filter(
            :organization_guid => org.guid,
          )
          # FIXME: don't skip validation
          org.billing_enabled = true
          org.save(:validate => false)
          ds.count.should == 4
        end

        it "should emit create events for provisioned services" do
          ds = ServiceCreateEvent.filter(
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
        QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => false)
      end

      let(:paid_quota) do
        QuotaDefinition.make(:total_services => 1,
          :non_basic_services_allowed => true)
      end

      let(:unlimited_quota) do
        QuotaDefinition.make(:total_services => -1,
          :non_basic_services_allowed => true)
      end

      let(:free_plan) { ServicePlan.make(:free => true)}

      describe "#service_instance_quota_remaining?" do
        it "should return true when quota is not reached" do
          org = Organization.make(:quota_definition => free_quota)
          space = Space.make(:organization => org)
          org.service_instance_quota_remaining?.should be_true
        end

        it "should return false when quota is reached" do
          org = Organization.make(:quota_definition => free_quota)
          space = Space.make(:organization => org)
          org.service_instance_quota_remaining?.should be_true
          ManagedServiceInstance.make(:space => space,
                                       :service_plan => free_plan).
            save(:validate => false)
          org.refresh
          org.service_instance_quota_remaining?.should be_false
        end

        it "returns true when the limit is -1 (unlimited)" do
          org = Organization.make(:quota_definition => unlimited_quota)
          space = Space.make(:organization => org)
          org.service_instance_quota_remaining?.should be_true
        end
      end

      describe "#paid_services_allowed" do
        it "should return true when org has paid quota" do
          org = Organization.make(:quota_definition => paid_quota)
          org.paid_services_allowed?.should be_true
        end

        it "should return false when org has free quota" do
          org = Organization.make(:quota_definition => free_quota)
          org.paid_services_allowed?.should be_false
        end
      end
    end

    context "memory quota" do
      let(:quota) do
        QuotaDefinition.make(:memory_limit => 500)
      end

      it "should return the memory available when no apps are running" do
        org = Organization.make(:quota_definition => quota)

        org.memory_remaining.should == 500
      end

      it "should return the memory remaining when apps are consuming memory" do
        org = Organization.make(:quota_definition => quota)
        space = Space.make(:organization => org)
        AppFactory.make(:space => space,
                         :memory => 200,
                         :instances => 2)
        AppFactory.make(:space => space,
                         :memory => 50,
                         :instances => 1)

        org.memory_remaining.should == 50
      end
    end

    describe "#destroy" do
      let(:org) { Organization.make }
      let(:space) { Space.make(:organization => org) }

      before { org.reload }

      it "destroys all apps" do
        app = AppFactory.make(:space => space)
        expect { org.destroy(savepoint: true) }.to change { App[:id => app.id] }.from(app).to(nil)
      end

      it "destroys all spaces" do
        expect { org.destroy(savepoint: true) }.to change { Space[:id => space.id] }.from(space).to(nil)
      end

      it "destroys all service instances" do
        service_instance = ManagedServiceInstance.make(:space => space)
        expect { org.destroy(savepoint: true) }.to change { ManagedServiceInstance[:id => service_instance.id] }.from(service_instance).to(nil)
      end

      it "destroys all service plan visibilities" do
        service_plan_visibility = ServicePlanVisibility.make(:organization => org)
        expect {
          org.destroy(savepoint: true)
        }.to change {
          ServicePlanVisibility.where(:id => service_plan_visibility.id).any?
        }.to(false)
      end


      it "destroys the owned domain" do
        domain = Domain.make(:owning_organization => org)
        expect { org.destroy(savepoint: true) }.to change { Domain[:id => domain.id] }.from(domain).to(nil)
      end

      it "nullify domains" do
        SecurityContext.set(nil, {'scope' => [VCAP::CloudController::Roles::CLOUD_CONTROLLER_ADMIN_SCOPE]})
        domain = Domain.make(:owning_organization => nil)
        domain.add_organization(org)
        domain.save
        expect { org.destroy(savepoint: true) }.to change { domain.reload.organizations.count }.by(-1)
      end
    end

    describe "#trial_db_allocated?" do
      let(:org) { Organization.make }
      let(:space) { Space.make :organization => org }
      let(:trial_db_guid) { ServicePlan.trial_db_guid }
      subject { org.trial_db_allocated? }

      context "when a trial db instance has not been allocated" do
        it "retruns false" do
          expect(subject).to eq false
        end
      end

      context "when a trial db instance has been allocated" do
        let(:service_plan) { ServicePlan.make :unique_id => trial_db_guid}
        it "returns true" do
          ManagedServiceInstance.make(:space => space, :service_plan => service_plan)
          expect(subject).to eq true
        end
      end
    end

    describe "#service_plan_quota_remaining?" do
      let(:org) do
        Organization.make :quota_definition => quota
      end

      let(:trial_db_guid) { ServicePlan.trial_db_guid }

      let!(:space) do
        Space.make(:organization => org)
      end

      subject { org.check_quota?(service_plan) }

      context "when the service plan requested is the trial db" do
        let(:service_plan) do
            ServicePlan.find(:unique_id => trial_db_guid) ||
              ServicePlan.make(:unique_id => trial_db_guid)
        end

        context "and the org's quota definition is paid" do
          context "and the number of total instances does not exceed the quota restriction" do
            let(:quota) do
              QuotaDefinition.make(:total_services => 1)
            end

            it "return an empty hash" do
              expect(subject).to be_empty
            end
          end

          context "and the number of total instances exceeds than the quota restriction" do
            let(:quota) do
              QuotaDefinition.make(:total_services => 0)
            end

            it "returns a :paid_quota_exceeded error on the org" do
              expect(subject).to eq({:type => :org, :name => :paid_quota_exceeded })
            end
          end

        end

        context "and the org's quota definition is unpaid" do
          let(:quota) do
            QuotaDefinition.make(:non_basic_services_allowed => false)
          end

          it "returns a :paid_services_not_allowed error on the service plan" do
            expect(subject).to eq({:type => :service_plan, :name => :paid_services_not_allowed })
          end
        end

        context "and the org's quota definition is trial" do
          let(:quota) do
            QuotaDefinition.find(:non_basic_services_allowed => false, :trial_db_allowed => true)
          end

          it "returns no error if the org has not allocated a trial db" do
            expect(subject).to be_empty
          end

          it "returns a :trial_quota_exceeded error if the org has allocated a trial db" do
            Organization.any_instance.stub(:trial_db_allocated?).and_return(true)
            expect(subject).to eq({ :type => :org, :name => :trial_quota_exceeded })
          end

        end
      end

      context "when the service plan requested is not trial db" do
        context "and the service plan is free" do
          let(:service_plan) { ServicePlan.make :free => true }

          context "and the number of total instances is less than the quota restriction" do
            let(:quota) { QuotaDefinition.make :total_services => 1 }
            it "returns no error" do
              expect(subject).to be_empty
            end
          end

          context "and the number of total instances is greater than the quota restriction" do
            let(:quota) do
              QuotaDefinition.make(:total_services => 0, :non_basic_services_allowed => false)
            end

            it "returns :free_quota_exceeded for the org" do
              expect(subject).to eq({ :type => :org, :name => :free_quota_exceeded })
            end
          end
        end

        context "and the quota is paid" do
          let(:service_plan) { ServicePlan.make }
          context "and the number of total instances is less than the quota restriction" do
            let(:quota) do
              QuotaDefinition.make(:total_services => 1, :non_basic_services_allowed => true)
            end

            it "returns no error" do
              expect(subject).to be_empty
            end
          end

          context "and the number of total instances is greater than the quota restriction" do
            let(:quota) do
              QuotaDefinition.make(:total_services => 0, :non_basic_services_allowed => true)
            end

            it "returns :paid_quota_exceeded error for the org" do
              expect(subject).to eq({ :type => :org, :name => :paid_quota_exceeded })
            end
          end
        end

        context "and the quota is unpaid and the service plan is not free" do
          let(:quota) do
            QuotaDefinition.make(:total_services => 1, :non_basic_services_allowed => false)
          end
          let(:service_plan) { ServicePlan.make :free => false }
          it "returns a :paid_services_not_allowed error for the service plan" do
            expect(subject).to eq({ :type => :service_plan, :name => :paid_services_not_allowed })
          end
        end
      end
    end

    describe "filter deleted apps" do
      let(:org) { Organization.make }
      let(:space) { Space.make(:organization => org) }

      context "when deleted apps exist in the organization" do
        it "should not return the deleted apps" do
          deleted_app = AppFactory.make(:space => space)
          deleted_app.soft_delete

          non_deleted_app = AppFactory.make(:space => space)

          org.apps.should == [non_deleted_app]
        end
      end
    end
  end
end
