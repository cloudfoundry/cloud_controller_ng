# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ServiceInstancesQuotaDefinition do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/service_instances_quota_definitions",
      :model                => Models::ServiceInstancesQuotaDefinition,
      :basic_attributes     => [:name, :non_basic_services_allowed, :total_services],
      :required_attributes  => [:name, :non_basic_services_allowed, :total_services],
      :unique_attributes    => :name,
    }
  end
end
