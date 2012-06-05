# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Models::Service do
  it_behaves_like "a CloudController model", {
    :required_attributes  => [:label, :provider, :url, :description, :version],
    :unique_attributes    => [:label, :provider],
    :sensitive_attributes => :crypted_password,
    :stripped_string_attributes => [:label, :provider],
    :one_to_zero_or_more   => {
      :service_plans      => lambda { |service| VCAP::CloudController::Models::ServicePlan.make }
    }
  }
end
