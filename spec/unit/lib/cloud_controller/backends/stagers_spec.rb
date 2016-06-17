require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Stagers do
    let(:config) { TestConfig.config }

    let(:message_bus) { instance_double(CfMessageBus::MessageBus) }
    let(:dea_pool) { instance_double(Dea::Pool) }
    let(:package_hash) { 'fake-package-hash' }
    let(:buildpack) { instance_double(AutoDetectionBuildpack, custom?: false) }
    let(:docker) { false }
    let(:custom_buildpacks_enabled?) { true }

    let(:app) do
      instance_double(App,
        docker?:                    docker,
        package_hash:               package_hash,
        buildpack:                  buildpack,
        custom_buildpacks_enabled?: custom_buildpacks_enabled?,
        buildpack_specified?:       false,
      )
    end

    subject(:stagers) do
      Stagers.new(config, message_bus, dea_pool)
    end

    describe '#validate_app' do
      context 'when the app package hash is blank' do
        let(:package_hash) { '' }

        it 'raises' do
          expect {
            subject.validate_app(app)
          }.to raise_error(CloudController::Errors::ApiError, /app package is invalid/)
        end
      end

      context 'when a custom buildpack is specified' do
        let(:buildpack) do
          instance_double(CustomBuildpack, custom?: true)
        end

        before do
          allow(app).to receive(:buildpack_specified?).and_return(true)
        end

        context 'and custom buildpacks are disabled' do
          let(:custom_buildpacks_enabled?) do
            false
          end

          it 'raises' do
            expect {
              subject.validate_app(app)
            }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
          end
        end
      end

      context 'when an admin buildpack is specified' do
        let(:buildpack) { instance_double(Buildpack, custom?: false) }

        before do
          allow(app).to receive(:buildpack_specified?).and_return(true)
          allow(Buildpack).to receive(:count).and_return(1)
        end

        context 'and custom buildpacks are disabled' do
          let(:custom_buildpacks_enabled?) do
            false
          end

          it 'does not raise' do
            expect {
              subject.validate_app(app)
            }.to_not raise_error
          end
        end
      end

      context 'with a docker app' do
        let(:buildpack) { instance_double(AutoDetectionBuildpack, custom?: true) }
        let(:docker) { true }

        context 'and Docker disabled' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: false)
          end

          it 'raises' do
            expect {
              subject.validate_app(app)
            }.to raise_error(CloudController::Errors::ApiError, /Docker support has not been enabled/)
          end
        end

        context 'and Docker enabled' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: true)
          end

          it 'does not raise' do
            expect { subject.validate_app(app) }.not_to raise_error
          end
        end
      end

      context 'when there are no buildpacks installed on the system' do
        before { Buildpack.dataset.delete }

        context 'and a custom buildpack is NOT specified' do
          it 'raises NoBuildpacksFound' do
            expect {
              subject.validate_app(app)
            }.to raise_error(CloudController::Errors::ApiError, /There are no buildpacks available/)
          end
        end

        context 'and a custom buildpack is specified' do
          let(:buildpack) do
            instance_double(CustomBuildpack, custom?: true)
          end

          it 'does not raise' do
            expect {
              subject.validate_app(app)
            }.not_to raise_error
          end
        end
      end
    end

    describe '#stager_for_app' do
      let(:stager) do
        stagers.stager_for_app(app)
      end

      context 'when the App is staging to Diego' do
        before do
          allow(app).to receive(:diego?).and_return(true)
        end

        it 'finds a diego stager' do
          expect(stagers).to receive(:diego_stager).with(app).and_call_original
          expect(stager).to be_a(Diego::Stager)
        end

        context 'when the app is docker' do
          let(:docker) { true }

          it 'finds a diego stager' do
            expect(stagers).to receive(:diego_stager).with(app).and_call_original
            expect(stager).to be_a(Diego::Stager)
          end
        end
      end

      context 'when the App is staging to the DEA' do
        before do
          allow(app).to receive(:diego?).and_return(false)
        end

        it 'finds a DEA backend' do
          expect(stagers).to receive(:dea_stager).with(app).and_call_original
          expect(stager).to be_a(Dea::Stager)
        end
      end
    end

    describe '#stager_for_package' do
      let(:package) { double(:package, app: app) }
      let(:lifecycle_type) { 'buildpack' }

      it 'finds a Diego backend' do
        stager = stagers.stager_for_package(package, lifecycle_type)
        expect(stager).to be_a(Diego::V3::Stager)
      end
    end
  end
end
