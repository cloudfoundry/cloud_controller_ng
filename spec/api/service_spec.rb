# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Service do

  it_behaves_like "a CloudController API", {
    :path                 => "/v2/services",
    :model                => VCAP::CloudController::Models::Service,
    :basic_attributes     => [:label, :provider, :url, :type, :description, :version, :info_url],
    :required_attributes  => [:label, :provider, :url, :type, :description, :version],
    :unique_attributes    => [:label, :provider],
    :one_to_many_collection_ids  => {
      :service_plans => lambda { |service| VCAP::CloudController::Models::ServicePlan.make }
    }
  }

end
