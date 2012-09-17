# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Permissions::SpaceAuditor do
    let(:obj)         { Models::Space.make }
    let(:not_granted) { Models::User.make }
    let(:granted) do
      user = make_user_for_space(obj)
      obj.add_auditor(user)
    end

    it_behaves_like "a cf permission", "app space auditor"
  end
end
