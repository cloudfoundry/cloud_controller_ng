# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Permissions::OrgManager do
  let(:obj)         { VCAP::CloudController::Models::Organization.make }
  let(:not_granted) { VCAP::CloudController::Models::User.make }
  let(:granted) do
    manager = VCAP::CloudController::Models::User.make
    obj.add_manager(manager)
  end

  it_behaves_like "a cf permission", "org manager"
end
