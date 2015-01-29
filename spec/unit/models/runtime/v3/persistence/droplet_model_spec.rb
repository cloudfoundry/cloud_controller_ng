# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe DropletModel do
    it { is_expected.to validates_includes DropletModel::DROPLET_STATES, :state, allow_missing: true }
  end
end
