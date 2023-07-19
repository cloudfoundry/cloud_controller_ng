require 'spec_helper'
require 'actions/v2/app_stage'

module VCAP::CloudController
  module V2
    RSpec.describe AppStage do
      let(:stagers) { instance_double(Stagers, validate_process: nil) }

      subject(:action) { AppStage.new(stagers: stagers) }

      describe '#stage' do
        let(:buildpack) { BuildpackLifecycleBuildpackModel.make(:custom_buildpack, buildpack_url: 'http://github.com/myorg/awesome-buildpack') }
        let(:buildpack_lifecycle_data) { BuildpackLifecycleDataModel.make(stack: 'my_stack', buildpack_lifecycle_buildpack_guids: [buildpack.guid]) }

        let(:app) { AppModel.make }

        let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }
        let(:build) { BuildModel.make(:buildpack, app: app, package: package, created_by_user_guid: 'user-guid') }
        let(:build_create) { instance_double(BuildCreate, create_and_stage_without_event: build, staging_response: 'staging-response') }

        before do
          allow(BuildCreate).to receive(:new).with(memory_limit_calculator: an_instance_of(NonQuotaValidatingStagingMemoryCalculator)).and_return(build_create)
          build.buildpack_lifecycle_data = buildpack_lifecycle_data
        end

        it 'delegates to BuildCreate with a BuildCreateMessage based on the process' do
          process = ProcessModel.make(memory: 765, disk_quota: 1234, app: app)
          process.reload

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:package]).to eq(package)
          end
        end

        it 'requests to start the app after staging' do
          process = ProcessModelFactory.make(memory: 765, disk_quota: 1234)

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:start_after_staging]).to be_truthy
          end
        end

        it 'provides a docker lifecycle for docker apps' do
          process = ProcessModelFactory.make(docker_image: 'some-image', memory: 765, disk_quota: 1234)

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:lifecycle].type).to equal(Lifecycles::DOCKER)
            expect(parameter_hash[:lifecycle].staging_message.staging_memory_in_mb).to equal(765)
            expect(parameter_hash[:lifecycle].staging_message.staging_disk_in_mb).to equal(1234)
          end
        end

        it 'provides a buildpack lifecyle for buildpack apps' do
          process = ProcessModelFactory.make(memory: 765, disk_quota: 1234)

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:lifecycle].type).to equal(Lifecycles::BUILDPACK)
            expect(parameter_hash[:lifecycle].staging_message.staging_memory_in_mb).to equal(765)
            expect(parameter_hash[:lifecycle].staging_message.staging_disk_in_mb).to equal(1234)
          end
        end

        it 'attaches the staging response to the app' do
          process = ProcessModelFactory.make
          action.stage(process)
          expect(process.last_stager_response).to eq('staging-response')
        end

        it 'validates the app before staging' do
          process = ProcessModelFactory.make
          allow(stagers).to receive(:validate_process).with(process).and_raise(StandardError.new)

          expect {
            action.stage(process)
          }.to raise_error(StandardError)

          expect(build_create).not_to have_received(:create_and_stage_without_event)
        end

        context 'handling BuildCreate errors' do
          let(:process) { ProcessModelFactory.make }

          context 'when BuildError error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(BuildCreate::BuildError.new('some error'))
            end

            it 'translates it to an ApiError' do
              expect { action.stage(process) }.to raise_error(CloudController::Errors::ApiError, /some error/) do |err|
                expect(err.details.name).to eq('AppInvalid')
              end
            end
          end

          context 'when MemorySpaceQuotaExceeded error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(
                BuildCreate::MemorySpaceQuotaExceeded.new('helpful message')
              )
            end

            it 'translates it to an ApiError' do
              expect { action.stage(process) }.to(raise_error(
                                                    CloudController::Errors::ApiError,
                /helpful message/
              )) { |err| expect(err.details.name).to eq('SpaceQuotaMemoryLimitExceeded') }
            end
          end

          context 'when MemoryOrgQuotaExceeded error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(
                BuildCreate::MemoryOrgQuotaExceeded.new('helpful message')
              )
            end

            it 'translates it to an ApiError' do
              expect { action.stage(process) }.to(raise_error(
                                                    CloudController::Errors::ApiError,
                /helpful message/
              )) { |err| expect(err.details.name).to eq('AppMemoryQuotaExceeded') }
            end
          end

          context 'when DiskLimitExceeded error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(BuildCreate::DiskLimitExceeded.new)
            end

            it 'translates it to an ApiError' do
              expect { action.stage(process) }.to raise_error(CloudController::Errors::ApiError, /too much disk requested/) do |err|
                expect(err.details.name).to eq('AppInvalid')
              end
            end
          end

          context 'when LogRateLimitSpaceQuotaExceeded error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(
                BuildCreate::LogRateLimitSpaceQuotaExceeded.new('helpful message')
              )
            end

            it 'translates it to an ApiError' do
              expect { action.stage(process) }.to(raise_error(CloudController::Errors::ApiError,
                /helpful message/)) { |err| expect(err.details.name).to eq('SpaceQuotaLogRateLimitExceeded') }
            end
          end

          context 'when LogRateLimitOrgQuotaExceeded error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(
                BuildCreate::LogRateLimitOrgQuotaExceeded.new('helpful message')
              )
            end

            it 'translates it to an ApiError' do
              expect { action.stage(process) }.to(raise_error(CloudController::Errors::ApiError,
                /helpful message/)) { |err| expect(err.details.name).to eq('OrgQuotaLogRateLimitExceeded') }
            end
          end
        end

        context 'telemetry' do
          let(:user_audit_info) do
            UserAuditInfo.new(
              user_email: 'my@email.com',
              user_name:  'user name',
              user_guid:  'userguid'
            )
          end
          let(:logger_spy) { spy('logger') }

          before do
            allow(VCAP::CloudController::TelemetryLogger).to receive(:logger).and_return(logger_spy)
            allow(UserAuditInfo).to receive(:from_context).and_return(user_audit_info)
            allow(BuildCreate).to receive(:new).and_call_original
            allow_any_instance_of(Diego::Stager).to receive(:stage).and_return 'staging-complete'
          end

          it 'logs build creates' do
            Timecop.freeze do
              buildpack = BuildpackLifecycleBuildpackModel.make(:custom_buildpack, buildpack_url: 'http://github.com/myorg/awesome-buildpack')
              buildpack_lifecycle_data = BuildpackLifecycleDataModel.make(stack: 'my_stack', buildpack_lifecycle_buildpack_guids: [buildpack.guid])

              app = AppModel.make
              app.buildpack_lifecycle_data = buildpack_lifecycle_data
              app.save
              process = ProcessModel.make(memory: 765, disk_quota: 1234, app: app)
              PackageModel.make(app: process.app, state: PackageModel::READY_STATE)

              action.stage(process)
              expected_json = {
                'telemetry-source' => 'cloud_controller_ng',
                'telemetry-time' => Time.now.to_datetime.rfc3339,
                'create-build' => {
                  'api-version' => 'v2',
                  'lifecycle' =>  'buildpack',
                  'buildpacks' =>  ['http://github.com/myorg/awesome-buildpack'],
                  'stack' =>  'my_stack',
                  'app-id' =>  OpenSSL::Digest::SHA256.hexdigest(process.app.guid),
                  'build-id' =>  OpenSSL::Digest::SHA256.hexdigest(process.latest_build.guid),
                  'user-id' =>  OpenSSL::Digest.hexdigest('SHA256', 'userguid'),
                }
              }
              expect(logger_spy).to have_received(:info).with(JSON.generate(expected_json))
            end
          end
        end
      end
    end
  end
end
