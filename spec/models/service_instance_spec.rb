# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::ServiceInstance do
    let(:service_instance) { VCAP::CloudController::Models::ServiceInstance.make }
    let(:email) { Sham.email }
    let(:guid) { Sham.guid }

    before do
      VCAP::CloudController::SecurityContext.stub(:current_user_email) { email }
    end

    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :service_plan, :space],
      :db_required_attributes => [:name],
      :unique_attributes   => [:space, :name],
      :stripped_string_attributes => :name,
      :many_to_one         => {
        :service_plan      => lambda { |service_instance| Models::ServicePlan.make },
        :space             => lambda { |service_instance| Models::Space.make },
      },
      :one_to_zero_or_more => {
        :service_bindings  => lambda { |service_instance|
          make_service_binding_for_service_instance(service_instance)
        }
      }
    }

    describe "#add_service_binding" do
      it "should not bind an app and a service instance from different app spaces" do
        Models::App.make(:space => service_instance.space)
        service_binding = Models::ServiceBinding.make
        expect {
          service_instance.add_service_binding(service_binding)
        }.to raise_error Models::ServiceInstance::InvalidServiceBinding
      end
    end

    describe "lifecycle" do
      context "service provisioning" do
        it "should deprovision a service on rollback after a create" do
          expect {
            Models::ServiceInstance.db.transaction do
              gw_client.should_receive(:unprovision)
              service_instance
              raise "something bad which causes the unprovision to happen"
            end
          }.to raise_error
        end

        it "should not deprovision a service on rollback after update" do
          expect {
            Models::ServiceInstance.db.transaction do
              service_instance.update(:name => "newname")
              raise "something bad"
            end
          }.to raise_error
        end
      end

      context "service deprovisioning" do
        it "should deprovision a service on destroy" do
          service_instance.client.should_receive(:unprovision).with(any_args)
          service_instance.destroy
        end
      end
    end

    context "billing" do
      context "creating a service instance" do
        it "should call ServiceCreateEvent.create_from_service_instance" do
          Models::ServiceCreateEvent.should_receive(:create_from_service_instance)
          Models::ServiceDeleteEvent.should_not_receive(:create_from_service_instance)
          service_instance
        end
      end

      context "destroying a service instance" do
        it "should call ServiceDeleteEvent.create_from_service_instance" do
          service_instance
          Models::ServiceCreateEvent.should_not_receive(:create_from_service_instance)
          Models::ServiceDeleteEvent.should_receive(:create_from_service_instance).with(service_instance)
          service_instance.destroy
        end
      end
    end

    describe "#as_summary_json" do
      subject { Models::ServiceInstance.make }

      it "returns detailed summary" do
        subject.as_summary_json.should == {
          :guid => subject.guid,
          :name => subject.name,
          :bound_app_count => 0,
          :service_plan => {
            :guid => subject.service_plan.guid,
            :name => subject.service_plan.name,
            :service => {
              :guid => subject.service_plan.service.guid,
              :label => subject.service_plan.service.label,
              :provider => subject.service_plan.service.provider,
              :version => subject.service_plan.service.version,
            }
          }
        }
      end
    end

    describe "#service_gateway_client" do
      let(:plan) do
        double("plan").tap do |p|
          p.stub(:service) {
            double("service").tap do |s|
              s.stub(:url => "https://fake.example.com/fake")
              s.stub(:service_auth_token => token)
              s.stub(:timeout => 999999)
            end
          }
        end
      end

      context "with missing service_auth_token" do
        let(:token) { nil }

        it "raises an error" do
          expect {
            VCAP::CloudController::Models::ServiceInstance.new.service_gateway_client(plan)
          }.to raise_error(VCAP::CloudController::Models::ServiceInstance::InvalidServiceBinding, /no service_auth_token/i)
        end
      end

      context "with service_auth_token" do
        let(:token) do
          double("token").tap do |t|
            t.stub(:token) { "le_token" }
          end
        end

        it "sets the service_gateway_client" do
          instance = VCAP::CloudController::Models::ServiceInstance.new
          instance.service_gateway_client(plan)

          expect(instance.client.instance_variable_get(:@url)).to eq("https://fake.example.com/fake")
          expect(instance.client.instance_variable_get(:@token)).to eq("le_token")
          expect(instance.client.instance_variable_get(:@timeout)).to eq(999999)
        end
      end
    end

    describe "#provision_on_gateway" do
      context "when a client exists" do
        it 'provisions the client' do
          provision_hash = nil
          VCAP::Services::Api::ServiceGatewayClientFake.any_instance.should_receive(:provision).with(any_args) do |h|
            provision_hash = h
            VCAP::Services::Api::GatewayHandleResponse.new(
              :service_id => '',
              :configuration => '',
              :credentials => '',
            )
          end
          service_instance

          expect(provision_hash).to eq(
           :label => "#{service_instance.service_plan.service.label}-#{service_instance.service_plan.service.version}",
           :name => service_instance.name,
           :email => email,
           :plan => service_instance.service_plan.name,
           :plan_option => {}, # TODO: remove this
           :provider => service_instance.service_plan.service.provider,
           :version => service_instance.service_plan.service.version,
           :space_guid => service_instance.space.guid,
           :organization_guid => service_instance.space.organization_guid
          )
        end

        it 'sets up the gateway' do
          service_instance
          expect(service_instance.gateway_name).to be_a String
          expect(service_instance.gateway_data).to be_a String
          expect(service_instance.credentials).to be_a Hash
        end
      end
    end

    context "quota" do
      let(:free_plan) { Models::ServicePlan.make(:free => true)}
      let(:paid_plan) { Models::ServicePlan.make(:free => false)}

      let(:free_quota) do
        Models::QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => false)
      end
      let(:paid_quota) do
        Models::QuotaDefinition.make(:total_services => 1,
                                     :non_basic_services_allowed => true)
      end

      context "exceed quota" do
        it "should raise paid quota error when paid quota is exceeded" do
          org = Models::Organization.make(:quota_definition => paid_quota)
          space = Models::Space.make(:organization => org)
          Models::ServiceInstance.make(:space => space,
                                       :service_plan => free_plan).
            save(:validate => false)
          space.refresh
          expect do
            Models::ServiceInstance.make(:space => space,
                                         :service_plan => free_plan)
          end.to raise_error(Sequel::ValidationFailed, /space paid_quota_exceeded/)
        end

        it "should raise free quota error when free quota is exceeded" do
          org = Models::Organization.make(:quota_definition => free_quota)
          space = Models::Space.make(:organization => org)
          Models::ServiceInstance.make(:space => space,
                                       :service_plan => free_plan).
            save(:validate => false)
          space.refresh
          expect do
            Models::ServiceInstance.make(:space => space,
                                         :service_plan => free_plan)
          end.to raise_error(Sequel::ValidationFailed, /space free_quota_exceeded/)
        end

        it "should not raise error when quota is not exceeded" do
          org = Models::Organization.make(:quota_definition => paid_quota)
          space = Models::Space.make(:organization => org)
          expect do
            Models::ServiceInstance.make(:space => space,
                                         :service_plan => free_plan)
          end.to_not raise_error
        end
      end

      context "create free services" do
        it "should not raise error when created in free quota" do
          org = Models::Organization.make(:quota_definition => free_quota)
          space = Models::Space.make(:organization => org)
          expect do
            Models::ServiceInstance.make(:space => space,
                                         :service_plan => free_plan)
          end.to_not raise_error
        end

        it "should not raise error when created in paid quota" do
          org = Models::Organization.make(:quota_definition => paid_quota)
          space = Models::Space.make(:organization => org)
          expect do
            Models::ServiceInstance.make(:space => space,
                                         :service_plan => free_plan)
          end.to_not raise_error
        end
      end

      context "create paid services" do
        it "should raise error when created in free quota" do
          org = Models::Organization.make(:quota_definition => free_quota)
          space = Models::Space.make(:organization => org)
          expect do
            Models::ServiceInstance.make(:space => space,
                                         :service_plan => paid_plan)
          end.to raise_error(Sequel::ValidationFailed,
                             /service_plan paid_services_not_allowed/)
        end

        it "should not raise error when created in paid quota" do
          org = Models::Organization.make(:quota_definition => paid_quota)
          space = Models::Space.make(:organization => org)
          expect do
            Models::ServiceInstance.make(:space => space,
                                         :service_plan => paid_plan)
          end.to_not raise_error
        end
      end
    end
  end
end
