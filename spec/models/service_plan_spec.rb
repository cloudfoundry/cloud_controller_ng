# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::ServicePlan do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :free, :description, :service],
      :unique_attributes => [:service, :name],
      :stripped_string_attributes => :name,
      :many_to_one => {
        :service => {
          :delete_ok => true,
          :create_for => lambda { |service_plan| Models::Service.make },
        },
      },
      :one_to_zero_or_more => {
        :service_instances => lambda { |service_plan| Models::ServiceInstance.make }
      },
    }

    describe "#destroy" do
      let(:service_plan) { Models::ServicePlan.make }

      it "destroys all service instances" do
        service_instance = Models::ServiceInstance.make(:service_plan => service_plan)
        expect { service_plan.destroy }.to change { Models::ServiceInstance.where(:id => service_instance.id).count }.by(-1)
      end
    end

    describe "validation" do
      let(:service) { Models::Service.make }

      context "when there is no service set" do
        it "does not set the unique_id" do
          service_plan = Models::ServicePlan.new
          service_plan.valid?
          service_plan.unique_id.should be_nil
        end
      end

      context "when unique_id is not provided" do
        it "sets a default" do
          service_plan = Models::ServicePlan.new(name: '1herd', service: service)
          service_plan.valid?
          service_plan.unique_id.should_not be_empty
        end

        it "sets a unique unique_id" do
          service_plan_1 = Models::ServicePlan.new(name: '1herd', service: service)
          service_plan_2 = Models::ServicePlan.new(name: '2herds', service: service)
          service_plan_1.valid?
          service_plan_2.valid?
          service_plan_1.unique_id.should_not == service_plan_2.unique_id
        end
      end

      context "when unique_id is provided" do
        it "uses provided unique_id" do
          service_plan = Models::ServicePlan.new(unique_id: "glue-factory", service: service)
          expect {
            service_plan.valid?
          }.not_to change(service_plan, :unique_id)
        end
      end
    end
  end
end
