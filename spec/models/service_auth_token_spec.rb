# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::ServiceAuthToken do
    it_behaves_like "a CloudController model", {
      :required_attributes  => [:label, :provider, :token],
      :unique_attributes    => [:label, :provider],
      :sensitive_attributes => :token,
      :extra_json_attributes => :token,
      :stripped_string_attributes => [:label, :provider],
      :ci_attributes              => [:label, :provider]
    }
  end
end
