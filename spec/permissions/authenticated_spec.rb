# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Permissions::Authenticated do
  it_behaves_like "a cf permission", "authenticated",
    VCAP::CloudController::Models::User.make,
    nil
end
