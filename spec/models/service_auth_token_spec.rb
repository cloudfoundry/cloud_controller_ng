# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Models::ServiceAuthToken do
  it_behaves_like "a CloudController model", {
    :required_attributes  => [:label, :provider, :crypted_token],
    :unique_attributes    => [:label, :provider],
    :sensitive_attributes => :crypted_token,
    :extra_json_attributes => :token,
    :stripped_string_attributes => [:label, :provider]
  }
end
end
