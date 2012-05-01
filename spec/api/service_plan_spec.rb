# Copyright (c) 2009-2011 VMware, Inc.

require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::CloudController::ServicePlan do
  let(:service_plan) { VCAP::CloudController::Models::ServicePlan.make }
  let(:service) { VCAP::CloudController::Models::Service.make }

  it_behaves_like "a CloudController API", {
    :path                 => '/v2/service_plans',
    :model                => VCAP::CloudController::Models::ServicePlan,
    :basic_attributes     => [:name, :description, :service_id],
    :required_attributes  => [:name, :description, :service_id],
    :unique_attributes    => [:name, :service_id],
    :one_to_many_collection_ids  => {
      :service_instances => lambda { |service_plan| VCAP::CloudController::Models::ServiceInstance.make }
    }
  }

  it_behaves_like "an authenticated CloudController API",
    VCAP::CloudController::Models::ServicePlan,
    [
      ['/v2/service_plans', :post, 201, 403, 401, { :name => Sham.name, :description => Sham.description, :service_id => '#{service.id}' } ],
      ['/v2/service_plans', :get, 200, 403, 401],
      ['/v2/service_plans/#{service_plan.id}', :put, 201, 403, 401, { :label => '#{service_plan.name}_renamed' }],
      ['/v2/service_plans/#{service_plan.id}', :delete, 204, 403, 401],
    ]

end
