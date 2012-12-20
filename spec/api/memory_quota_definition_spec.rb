# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::MemoryQuotaDefinition do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/memory_quota_definitions",
      :model                => Models::MemoryQuotaDefinition,
      :basic_attributes     => [:name, :free_limit, :paid_limit],
      :required_attributes  => [:name, :free_limit, :paid_limit],
      :unique_attributes    => :name,
    }
  end
end
