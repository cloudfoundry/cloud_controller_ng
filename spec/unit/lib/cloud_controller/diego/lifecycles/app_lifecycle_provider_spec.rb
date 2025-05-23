require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppLifecycleProvider do
    describe '#provide_for_create' do
      let(:message) { AppCreateMessage.new(request) }

      context 'when lifecycle type is requested on the message' do
        let(:request) { { lifecycle: { type: type, data: {} } } }

        context 'docker type' do
          let(:type) { 'docker' }

          it 'returns a AppDockerLifecycle' do
            expect(AppLifecycleProvider.provide_for_create(message)).to be_a(AppDockerLifecycle)
          end
        end

        context 'buildpack type' do
          let(:type) { 'buildpack' }

          it 'returns a AppBuildpackLifecycle' do
            expect(AppLifecycleProvider.provide_for_create(message)).to be_a(AppBuildpackLifecycle)
          end
        end
      end

      context 'when lifecycle type is not requested on the message' do
        let(:request) { {} }

        context 'default_app_lifecycle is set to buildpack' do
          before do
            TestConfig.override(default_app_lifecycle: 'buildpack')
          end

          it 'returns a AppBuildpackLifecycle' do
            expect(AppLifecycleProvider.provide_for_create(message)).to be_a(AppBuildpackLifecycle)
          end
        end

        context 'default_app_lifecycle is set to cnb' do
          before do
            TestConfig.override(default_app_lifecycle: 'cnb')
          end

          it 'returns a AppCNBLifecycle' do
            expect(AppLifecycleProvider.provide_for_create(message)).to be_a(AppCNBLifecycle)
          end
        end
      end
    end

    describe '#provide_for_update' do
      let(:app) { AppModel.make }
      let(:message) { AppUpdateMessage.new(request) }

      context 'when lifecycle type is requested on the message' do
        let(:request) { { lifecycle: { type: type, data: {} } } }

        context 'docker type' do
          let(:type) { 'docker' }

          it 'returns a AppDockerLifecycle' do
            expect(AppLifecycleProvider.provide_for_update(message, app)).to be_a(AppDockerLifecycle)
          end
        end

        context 'cnb type' do
          let(:type) { 'cnb' }

          it 'returns a CNBDockerLifecycle' do
            expect(AppLifecycleProvider.provide_for_update(message, app)).to be_a(AppCNBLifecycle)
          end
        end

        context 'buildpack type' do
          let(:type) { 'buildpack' }

          it 'returns a AppBuildpackLifecycle' do
            expect(AppLifecycleProvider.provide_for_update(message, app)).to be_a(AppBuildpackLifecycle)
          end
        end
      end

      context 'when lifecycle type is not requested on the message' do
        let(:request) { {} }

        context 'the app is buildpack type' do
          let(:app) { AppModel.make(:buildpack) }

          it 'returns a AppBuildpackLifecycle' do
            expect(AppLifecycleProvider.provide_for_update(message, app)).to be_a(AppBuildpackLifecycle)
          end
        end

        context 'the app is docker type' do
          let(:app) { AppModel.make(:docker) }

          it 'returns a AppDockerLifecycle' do
            expect(AppLifecycleProvider.provide_for_update(message, app)).to be_a(AppDockerLifecycle)
          end
        end
      end
    end
  end
end
