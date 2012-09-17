# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Permissions::Anonymous do
    let(:obj)         { Models::Organization.make }
    let(:granted)     { nil }
    let(:not_granted) { Models::User.make }

    it_behaves_like "a cf permission", "anonymous", true
  end
end
