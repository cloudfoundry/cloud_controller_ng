# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Permissions::CFAdmin do
  it_behaves_like "a cf permission", "admin",
    VCAP::CloudController::Models::User.make(:admin => true),
    VCAP::CloudController::Models::User.make
end
