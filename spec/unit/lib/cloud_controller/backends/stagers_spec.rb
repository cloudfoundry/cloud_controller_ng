require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Stagers do
    subject(:stagers) { Stagers.new(config) }
    let(:config) { TestConfig.config_instance }

    describe '#validate_app' do
      let!(:admin_buildpack) { Buildpack.make(name: 'admin-buildpack') }
      let(:buildpack_lifecycle_data) { BuildpackLifecycleDataModel.make(buildpacks: ['admin-buildpack']) }
      let(:app_model) { AppModel.make }
      let(:process_model) { ProcessModelFactory.make(:buildpack, app: app_model) }

      before do
        app_model.update(buildpack_lifecycle_data:)
      end

      context 'when the app package hash is blank' do
        before { PackageModel.make(package_hash: nil, sha256_checksum: '', app: process_model) }

        it 'raises' do
          expect do
            subject.validate_process(process_model)
          end.to raise_error(CloudController::Errors::ApiError, /app package is invalid/)
        end
      end

      context 'with a docker app' do
        let(:app_model) { AppModel.make(:docker) }
        let(:app) { ProcessModelFactory.make(app: app_model, docker_image: 'docker/image') }

        before { app_model.update(buildpack_lifecycle_data: nil) }

        context 'and Docker disabled' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: false)
          end

          it 'raises' do
            expect do
              subject.validate_process(process_model)
            end.to raise_error(CloudController::Errors::ApiError, /Docker support has not been enabled/)
          end
        end

        context 'and Docker enabled' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: true)
          end

          it 'does not raise' do
            expect { subject.validate_process(process_model) }.not_to raise_error
          end
        end
      end

      context 'with a cnb app' do
        let(:app_model) { AppModel.make(:cnb) }
        let(:app) { ProcessModelFactory.make(app: app_model, cnb: true) }

        before { app_model.update(buildpack_lifecycle_data: nil) }

        context 'and CNB disabled' do
          before do
            FeatureFlag.create(name: 'diego_cnb', enabled: false)
          end

          it 'raises' do
            expect do
              subject.validate_process(process_model)
            end.to raise_error(CloudController::Errors::ApiError, /Cloud Native Buildpacks support has not been enabled/)
          end
        end

        context 'and CNB enabled' do
          before do
            FeatureFlag.create(name: 'diego_cnb', enabled: true)
          end

          it 'does not raise' do
            expect { subject.validate_process(process_model) }.not_to raise_error
          end
        end
      end

      context 'when there are no buildpacks installed on the system' do
        before { Buildpack.dataset.delete }

        context 'and an admin buildpack is specified' do
          let(:buildpack_lifecycle_data) do
            BuildpackLifecycleDataModel.make(buildpacks: %w[https://buildpacks.gov admin-buildpack])
          end

          it 'raises an error' do
            expect do
              subject.validate_process(process_model)
            end.to raise_error(CloudController::Errors::ApiError, /There are no buildpacks available/)
          end
        end

        context 'and custom buildpacks are specified' do
          let(:buildpack_lifecycle_data) do
            BuildpackLifecycleDataModel.make(buildpacks: %w[https://buildpacks.gov http://custom-buildpack.example.com])
          end

          it 'does not raise' do
            expect do
              subject.validate_process(process_model)
            end.not_to raise_error
          end
        end
      end
    end

    describe '#stager_for_build' do
      let(:build) { BuildModel.make }

      it 'finds a diego stager' do
        stager = stagers.stager_for_build(build)
        expect(stager).to be_a(Diego::Stager)
      end
    end
  end
end
