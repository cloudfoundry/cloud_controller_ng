require 'spec_helper'
require_relative 'lifecycle_shared'

module VCAP::CloudController
  RSpec.describe KpackLifecycle do
    subject(:lifecycle) { KpackLifecycle.new(package, staging_message) }
    let(:app) { AppModel.make }
    let(:package) { PackageModel.make(type: PackageModel::BITS_TYPE, app: app) }
    let(:staging_message) { BuildCreateMessage.new({}) }

    subject(:kpack_lifecycle) { KpackLifecycle.new(package, staging_message) }

    it_behaves_like 'a lifecycle'

    context ('when the build specifies buildpacks') do

      # Current test failure: uninitialized constant VCAP::CloudController::KpackBuildpack
      let(:stubbed_data) { [ KpackBuildpack.new(name: 'some-buildpack') ] }
      let(:request_data) do
        {
            buildpacks: ['some-buildpack']
        }
      end
      let(:staging_message) { BuildCreateMessage.new(lifecycle: { data: request_data, type: 'kpack' }) }

      before do
        allow(KpackBuildpackListFetcher).to receive(:fetch).with(["some-buildpack"]).and_return(stubbed_data)
      end
      it 'saves kpack buildpacks to the lifecyle' do
        expect(kpack_lifecycle.buildpack_infos).to eq(stubbed_data)
        expect(KpackBuildpackListFetcher).to have_received(:fetch).with(['some-buildpack'])
      end
    end

  end
end

