require 'spec_helper'

module VCAP::CloudController
  describe LifecycleProvider do
    let(:package) { PackageModel.make }
    let(:message) { DropletCreateMessage.new(request) }

    context 'when lifecycle type is requested on the message' do
      let(:request) { { lifecycle: { type: type, data: {} } } }

      context 'docker type' do
        let(:type) { 'docker' }

        it 'returns a DockerLifecycle' do
          expect(LifecycleProvider.provide(package, message)).to be_a(DockerLifecycle)
        end
      end

      context 'buildpack type' do
        let(:type) { 'buildpack' }

        it 'returns a BuildpackLifecycle' do
          expect(LifecycleProvider.provide(package, message)).to be_a(BuildpackLifecycle)
        end
      end
    end

    context 'when lifecycle type is not requested on the message' do
      let(:request) { {} }
      let(:package) { PackageModel.make(app_guid: app.guid) }

      context 'when the app defaults to buildpack' do
        let(:app) { AppModel.make(:buildpack) }

        it 'returns a BuildpackLifecycle' do
          expect(LifecycleProvider.provide(package, message)).to be_a(BuildpackLifecycle)
        end
      end

      context 'when the app defaults to docker' do
        let(:app) { AppModel.make(:docker) }

        it 'returns a DockerLifecycle' do
          expect(LifecycleProvider.provide(package, message)).to be_a(DockerLifecycle)
        end
      end
    end
  end
end
