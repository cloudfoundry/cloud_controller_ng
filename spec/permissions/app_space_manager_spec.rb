# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Permissions::AppSpaceManager do
  let(:obj)         { VCAP::CloudController::Models::AppSpace.make }
  let(:not_granted) { VCAP::CloudController::Models::User.make }
  let(:granted) do
    manager = make_user_for_app_space(obj)
    obj.add_manager(manager)
  end

  it_behaves_like "a cf permission", "app space manager"
end
