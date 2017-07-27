require 'spec_helper'
require 'actions/v2/app_stage'

module VCAP::CloudController
  module V2
    RSpec.describe AppStage do
      let(:stagers) { instance_double(Stagers, validate_process: nil) }

      subject(:action) { described_class.new(stagers: stagers) }

      describe '#stage' do
        let(:build_create) { instance_double(BuildCreate, create_and_stage_without_event: nil, staging_response: 'staging-response') }

        before do
          allow(BuildCreate).to receive(:new).with(memory_limit_calculator: an_instance_of(NonQuotaValidatingStagingMemoryCalculator)).and_return(build_create)
        end

        it 'delegates to BuildCreate with a BuildCreateMessage based on the process' do
          process = ProcessModel.make(memory: 765, disk_quota: 1234)
          package = PackageModel.make(app: process.app, state: PackageModel::READY_STATE)
          process.reload

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:package]).to eq(package)
          end
        end

        it 'requests to start the app after staging' do
          process = AppFactory.make(memory: 765, disk_quota: 1234)

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:start_after_staging]).to be_truthy
          end
        end

        it 'provides a docker lifecycle for docker apps' do
          process = AppFactory.make(docker_image: 'some-image', memory: 765, disk_quota: 1234)

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:lifecycle].type).to equal(Lifecycles::DOCKER)
            expect(parameter_hash[:lifecycle].staging_message.staging_memory_in_mb).to equal(765)
            expect(parameter_hash[:lifecycle].staging_message.staging_disk_in_mb).to equal(1234)
          end
        end

        it 'provides a buildpack lifecyle for buildpack apps' do
          process = AppFactory.make(memory: 765, disk_quota: 1234)

          action.stage(process)

          expect(build_create).to have_received(:create_and_stage_without_event) do |parameter_hash|
            expect(parameter_hash[:lifecycle].type).to equal(Lifecycles::BUILDPACK)
            expect(parameter_hash[:lifecycle].staging_message.staging_memory_in_mb).to equal(765)
            expect(parameter_hash[:lifecycle].staging_message.staging_disk_in_mb).to equal(1234)
          end
        end

        it 'attaches the staging response to the app' do
          process = AppFactory.make
          action.stage(process)
          expect(process.last_stager_response).to eq('staging-response')
        end

        it 'validates the app before staging' do
          process = AppFactory.make
          allow(stagers).to receive(:validate_process).with(process).and_raise(StandardError.new)

          expect {
            action.stage(process)
          }.to raise_error(StandardError)

          expect(build_create).not_to have_received(:create_and_stage_without_event)
        end

        describe 'handling BuildCreate errors' do
          let(:process) { AppFactory.make }

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

          context 'when SpaceQuotaExceeded error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(
                BuildCreate::SpaceQuotaExceeded.new('helpful message')
              )
            end

            it 'translates it to an ApiError' do
              expect { action.stage(process) }.to(raise_error(
                                                    CloudController::Errors::ApiError,
                /helpful message/
              )) { |err| expect(err.details.name).to eq('SpaceQuotaMemoryLimitExceeded') }
            end
          end

          context 'when OrgQuotaExceeded error is raised' do
            before do
              allow(build_create).to receive(:create_and_stage_without_event).and_raise(
                BuildCreate::OrgQuotaExceeded.new('helpful message')
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
        end
      end
    end
  end
end
