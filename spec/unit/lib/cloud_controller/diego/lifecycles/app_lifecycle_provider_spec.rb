require 'spec_helper'

module VCAP::CloudController
  describe AppLifecycleProvider do
    context 'when creating an app' do
      let(:app) { nil }
      let(:message) { AppCreateMessage.new(request) }

      context 'when lifecycle type is requested on the message' do
        let(:request) { { lifecycle: { type: type, data: {} } } }

        context 'docker type' do
          let(:type) { 'docker' }

          it 'returns a AppDockerLifecycle' do
            expect(AppLifecycleProvider.provide(message, app)).to be_a(AppDockerLifecycle)
          end
        end

        context 'buildpack type' do
          let(:type) { 'buildpack' }

          it 'returns a AppBuildpackLifecycle' do
            expect(AppLifecycleProvider.provide(message, app)).to be_a(AppBuildpackLifecycle)
          end
        end
      end

      context 'when lifecycle type is not requested on the message' do
        let(:request) { {} }

        it 'returns a AppBuildpackLifecycle' do
          expect(AppLifecycleProvider.provide(message, app)).to be_a(AppBuildpackLifecycle)
        end
      end
    end

    context 'when updating an app' do
      let(:app) { AppModel.make }
      let(:message) { AppUpdateMessage.new(request) }

      context 'when lifecycle type is requested on the message' do
        let(:request) { { lifecycle: { type: type, data: {} } } }

        context 'docker type' do
          let(:type) { 'docker' }

          it 'returns a AppDockerLifecycle' do
            expect(AppLifecycleProvider.provide(message, app)).to be_a(AppDockerLifecycle)
          end
        end

        context 'buildpack type' do
          let(:type) { 'buildpack' }

          it 'returns a AppBuildpackLifecycle' do
            expect(AppLifecycleProvider.provide(message, app)).to be_a(AppBuildpackLifecycle)
          end
        end
      end

      context 'when lifecycle type is not requested on the message' do
        let(:request) { {} }

        context 'the app is buildpack type' do
          let(:app) { AppModel.make(:buildpack) }

          it 'returns a AppBuildpackLifecycle' do
            expect(AppLifecycleProvider.provide(message, app)).to be_a(AppBuildpackLifecycle)
          end
        end

        context 'the app is docker type' do
          let(:app) { AppModel.make(:docker) }

          it 'returns a AppDockerLifecycle' do
            expect(AppLifecycleProvider.provide(message, app)).to be_a(AppDockerLifecycle)
          end
        end
      end
    end
  end
end
