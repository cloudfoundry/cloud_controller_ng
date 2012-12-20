# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::MemoryQuotaDefinition do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :free_limit, :paid_limit],
      :unique_attributes   => [:name],
    }
  end
end
