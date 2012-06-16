# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Permissions::Authenticated do
  let(:obj)         { VCAP::CloudController::Models::Organization.make }
  let(:granted)     { VCAP::CloudController::Models::User.make }
  let(:not_granted) { nil }

  it_behaves_like "a cf permission", "authenticated"
end
end
