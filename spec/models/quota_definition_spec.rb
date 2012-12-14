# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::QuotaDefinition do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:name, :non_basic_services_allowed, :total_services],
      :unique_attributes   => [:name]
    }
  end
end
