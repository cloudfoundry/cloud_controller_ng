# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ServiceAuthToken do

    it_behaves_like "a CloudController API", {
      :path                 => "/v2/service_auth_tokens",
      :model                => Models::ServiceAuthToken,
      :basic_attributes     => [:label, :provider],
      :required_attributes  => [:label, :provider, :token],
      :unique_attributes    => [:label, :provider],
      :ci_attributes        => [:label, :provider],
      :extra_attributes     => :token,
      :sensitive_attributes => :token
    }

  end
end
