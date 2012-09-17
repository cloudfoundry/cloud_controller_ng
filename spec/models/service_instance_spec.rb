# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::ServiceInstance do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :service_plan, :space],
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

    context "bad relationships" do
      let(:service_instance) { Models::ServiceInstance.make }

      context "service binding" do
        it "should not bind an app and a service instance from different app spaces" do
          app = Models::App.make(:space => service_instance.space)
          service_binding = Models::ServiceBinding.make
          lambda {
            service_instance.add_service_binding(service_binding)
          }.should raise_error Models::ServiceInstance::InvalidServiceBinding
        end
      end
    end

    context "provisioning" do
      let(:gw_client) { double(:client) }

      let(:token)   { Models::ServiceAuthToken.make }
      let(:service) { Models::Service.make(:label => token.label,
                                           :provider => token.provider) }
      let(:service_plan) { Models::ServicePlan.make(:service => service) }

      let(:provision_resp) do
        VCAP::Services::Api::GatewayHandleResponse.new(
          :service_id => "gwname",
          :configuration => "abc",
          :credentials => { :password => "foo" }
        )
      end

      before do
        client = VCAP::Services::Api::ServiceGatewayClient
        client.stub(:new).and_return(gw_client)
      end

      context "service provisioning" do
        it "should provision a service on create" do
          gw_client.should_receive(:provision).and_return(provision_resp)
          instance = Models::ServiceInstance.make(:service_plan => service_plan)
          instance.gateway_name.should == "gwname"
          instance.gateway_data.should == "abc"
          instance.credentials.should == { "password" => "foo" }
        end

        it "should deprovision a service on rollback after a create" do
          lambda {
            Models::ServiceInstance.db.transaction do
              gw_client.should_receive(:provision).and_return(provision_resp)
              gw_client.should_receive(:unprovision)
              instance = Models::ServiceInstance.make(:service_plan => service_plan)
              raise "something bad"
            end
          }.should raise_error
        end

        it "should not deprovision a service on rollback after update" do
          gw_client.should_receive(:provision).and_return(provision_resp)
          instance = Models::ServiceInstance.make(:service_plan => service_plan)
          lambda {
            Models::ServiceInstance.db.transaction do
              instance.update(:name => "newname")
              raise "something bad"
            end
          }.should raise_error
        end
      end

      context "service deprovisioning" do
        it "should deprovision a service on destroy" do
          gw_client.should_receive(:provision).and_return(provision_resp)
          instance = Models::ServiceInstance.make(:service_plan => service_plan)

          gw_client.should_receive(:unprovision).with(:service_id => "gwname")
          instance.destroy
        end
      end
    end
  end
end
