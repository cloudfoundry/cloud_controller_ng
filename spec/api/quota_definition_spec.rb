# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::QuotaDefinition do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/quota_definitions",
      :model                => Models::QuotaDefinition,
      :basic_attributes     => [:name, :non_basic_services_allowed,
                                :total_services, :free_memory_limit,
                                :paid_memory_limit],
      :required_attributes  => [:name, :non_basic_services_allowed,
                                :total_services, :free_memory_limit,
                                :paid_memory_limit],
      :unique_attributes    => :name,
    }
  end
end
