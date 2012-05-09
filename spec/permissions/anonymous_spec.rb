# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Permissions::Anonymous do
  it_behaves_like "a cf permission", "anonymous",
    nil,
    VCAP::CloudController::Models::User.make,
    true
end
