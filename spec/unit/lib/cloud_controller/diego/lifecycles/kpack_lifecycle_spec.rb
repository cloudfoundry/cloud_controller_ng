require 'spec_helper'
require_relative 'lifecycle_shared'

module VCAP::CloudController
  RSpec.describe KpackLifecycle do
    subject(:lifecycle) { KpackLifecycle.new(package, staging_message) }
    let(:app) { AppModel.make }
    let(:package) { PackageModel.make(type: PackageModel::BITS_TYPE, app: app) }
    let(:staging_message) { BuildCreateMessage.new({}) }

    it_behaves_like 'a lifecycle'
  end
end
