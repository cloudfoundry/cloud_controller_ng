# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe PackageModel do
    it { is_expected.to validates_includes PackageModel::PACKAGE_STATES, :state, allow_missing: true }
  end
end
