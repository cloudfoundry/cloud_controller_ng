# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
describe Permissions::CFAdmin do
  let(:obj)         { VCAP::CloudController::Models::Organization.make }
  let(:not_granted) { VCAP::CloudController::Models::User.make }
  let(:granted)     { VCAP::CloudController::Models::User.make(:admin => true) }

  it_behaves_like "a cf permission", "admin"
end
end
