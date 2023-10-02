require 'spec_helper'
require 'membrane'
require 'cloud_controller/diego/failure_reason_sanitizer'
require 'cloud_controller/metrics/prometheus_updater'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

module VCAP::CloudController
  RSpec.describe StagingCompletionController do
    let(:buildpack_name) { 'the-pleasant-buildpack' }
    let(:buildpack_other_name) { 'valley' }
    let(:buildpack_version) { '3.1' }
    let!(:buildpack) { Buildpack.make(name: buildpack_name, sha256_checksum: 'mammoth') }
    let(:buildpack2_name) { 'my-brilliant-buildpack' }
    let(:buildpack2_other_name) { 'launderette' }
    let(:buildpack2_version) { '95' }
    let!(:buildpack2) { Buildpack.make(name: buildpack2_name, sha256_checksum: 'languid') }

    let(:buildpack_key) { buildpack.key }
    let(:detected_buildpack) { 'detected_buildpack' }
    let(:execution_metadata) { 'execution_metadata' }
    let(:staging_response) do
      {
        result: {
          lifecycle_type: 'buildpack',
          lifecycle_metadata: {
            buildpack_key:,
            detected_buildpack:
          },
          execution_metadata: execution_metadata,
          process_types: { web: 'start me' }
        }
      }
    end
    let(:statsd_updater) do
      instance_double(VCAP::CloudController::Metrics::StatsdUpdater,
                      report_staging_success_metrics: nil,
                      report_staging_failure_metrics: nil)
    end
    let(:prometheus_updater) do
      instance_double(VCAP::CloudController::Metrics::PrometheusUpdater,
                      report_staging_success_metrics: nil,
                      report_staging_failure_metrics: nil)
    end
    let(:one_hour) { 1.hour.to_i }
    let(:one_hour_in_nanoseconds) { (1.hour.to_i * 1e9).to_i }

    before do
      TestConfig.override(kubernetes: nil)

      allow(VCAP::CloudController::Metrics::StatsdUpdater).to receive(:new).and_return(statsd_updater)
      allow(VCAP::CloudController::Metrics::PrometheusUpdater).to receive(:new).and_return(prometheus_updater)
    end

    context 'staging a package through /droplet_completed (legacy for rolling deploy)' do
      let(:url) { "/internal/v3/staging/#{staging_guid}/droplet_completed" }
      let(:staged_app) { AppModel.make }
      let(:package) { PackageModel.make(state: 'READY', app_guid: staged_app.guid) }
      let(:droplet) { DropletModel.make(package_guid: package.guid, app_guid: staged_app.guid, state: DropletModel::STAGING_STATE) }
      let(:staging_guid) { droplet.guid }

      context 'when it is a docker app' do
        let(:droplet) { DropletModel.make(:docker, package_guid: package.guid, app_guid: staged_app.guid, state: DropletModel::STAGING_STATE) }

        it 'calls the stager with a build created from the droplet and the response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), staging_response, false)

          post url, MultiJson.dump(staging_response)

          build = BuildModel.last
          expect(build).not_to be_nil
          expect(build.lifecycle_type).to eq('docker')

          expect(last_response.status).to eq(200)
        end
      end

      context 'when it is a buildpack app' do
        it 'calls the stager with a build created from the droplet and the response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), staging_response, false)

          post url, MultiJson.dump(staging_response)

          build = BuildModel.last
          expect(build).not_to be_nil
          expect(build.lifecycle_type).to eq('buildpack')

          expect(last_response.status).to eq(200)
        end
      end

      it 'propagates api errors from staging_response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(524)
        expect(last_response.body).to match(/JobTimeout/)
      end

      context 'when receiving the callback directly from BBS' do
        let(:staging_result) do
          {
            lifecycle_type: 'buildpack',
            lifecycle_metadata: {
              buildpack_key:,
              detected_buildpack:
            },
            execution_metadata: execution_metadata,
            process_types: { web: 'start me' }
          }
        end
        let(:failure_reason) { '' }
        let(:sanitized_failure_reason) { double(:sanitized_failure_reason) }
        let(:staging_result_json) { MultiJson.dump(staging_result) }
        let(:staging_response) do
          {
            failed: failure_reason.present?,
            failure_reason: failure_reason,
            result: staging_result_json,
            created_at: (Time.now.utc.to_i - one_hour) * 1e9
          }
        end

        before do
          allow(Diego::FailureReasonSanitizer).to receive(:sanitize).with(failure_reason).and_return(sanitized_failure_reason)
        end

        it 'calls the stager with a build for the droplet and response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), { result: staging_result }, false)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end

        it 'propagates api errors from staging_response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(524)
          expect(last_response.body).to match(/JobTimeout/)
        end

        it 'emits metrics for staging success' do
          one_hour_in_nanoseconds = (1.hour.to_i * 1e9).to_i
          expect(statsd_updater).to receive(:report_staging_success_metrics).with(one_hour_in_nanoseconds)
          expect(prometheus_updater).to receive(:report_staging_success_metrics).with(one_hour_in_nanoseconds)
          Timecop.freeze(Time.now) do
            post url, MultiJson.dump(staging_response)
          end
        end

        context 'when staging failed' do
          let(:failure_reason) { 'something went wrong' }
          let(:staging_result_json) { nil }

          it 'passes down the sanitized version of the error to the diego stager' do
            expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), { error: sanitized_failure_reason }, false)

            post url, MultiJson.dump(staging_response)
          end

          it 'emits metrics for staging failure' do
            one_hour_in_nanoseconds = (1.hour.to_i * 1e9).to_i
            expect(statsd_updater).to receive(:report_staging_failure_metrics).with(one_hour_in_nanoseconds)
            expect(prometheus_updater).to receive(:report_staging_failure_metrics).with(one_hour_in_nanoseconds)
            Timecop.freeze(Time.now) do
              post url, MultiJson.dump(staging_response)
            end
          end
        end
      end

      context 'when the droplet does not exist' do
        let(:staging_guid) { 'asdf' }

        it 'returns 404' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(404)
          expect(last_response.body).to match(/Droplet not found/)
        end
      end

      context 'when the start query param has a true value' do
        it 'requests staging_complete with start' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), staging_response, true)

          post "#{url}?start=true", MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/MessageParseError/)
          end
        end
      end
    end

    describe '/build_completed' do
      let(:url) { "/internal/v3/staging/#{staging_guid}/build_completed" }
      let(:staged_app) { AppModel.make }
      let(:package) { PackageModel.make(state: 'READY', app_guid: staged_app.guid) }
      let!(:droplet) { DropletModel.make }
      let(:build) { BuildModel.make(package_guid: package.guid, app: staged_app) }
      let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(buildpacks: [buildpack_name], stack: 'cflinuxfs4', build: build) }
      let(:staging_guid) { build.guid }
      let(:buildpacks) do
        [
          {
            name: buildpack_other_name,
            version: buildpack_version,
            key: buildpack.key
          },
          {
            name: buildpack2_other_name,
            version: buildpack2_version,
            key: buildpack2.key
          }
        ]
      end

      before do
        build.droplet = droplet
      end

      it 'calls the stager with the build and response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), staging_response, false)

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(200)
      end

      it 'propagates api errors from staging_response' do
        expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

        post url, MultiJson.dump(staging_response)
        expect(last_response.status).to eq(524)
        expect(last_response.body).to match(/JobTimeout/)
      end

      context 'when receiving the callback directly from BBS' do
        let(:staging_result) do
          {
            lifecycle_type: 'buildpack',
            lifecycle_metadata: {
              buildpack_key:,
              detected_buildpack:,
              buildpacks:
            },
            execution_metadata: execution_metadata,
            process_types: { web: 'start me' }
          }
        end
        let(:failure_reason) { '' }
        let(:sanitized_failure_reason) { double(:sanitized_failure_reason) }
        let(:staging_result_json) { MultiJson.dump(staging_result) }
        let(:staging_response) do
          {
            failed: failure_reason.present?,
            failure_reason: failure_reason,
            result: staging_result_json,
            created_at: (Time.now.utc.to_i - one_hour) * 1e9
          }
        end

        before do
          allow(Diego::FailureReasonSanitizer).to receive(:sanitize).with(failure_reason).and_return(sanitized_failure_reason)
        end

        it 'calls the stager with the droplet and response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), { result: staging_result }, false)

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end

        it 'adds the buildpack info to the droplet' do
          allow_any_instance_of(BuildModel).to receive(:in_final_state?).and_return(false)
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
          droplet_buildpacks = droplet.buildpack_lifecycle_data&.buildpack_lifecycle_buildpacks
          expect(droplet_buildpacks&.size).to eq(2)
          buildback_lifecycle_buildpack1 = BuildpackLifecycleBuildpackModel.find(buildpack_name: 'valley')
          buildback_lifecycle_buildpack2 = BuildpackLifecycleBuildpackModel.find(buildpack_name: 'launderette')
          expect(droplet_buildpacks).to contain_exactly(buildback_lifecycle_buildpack1, buildback_lifecycle_buildpack2)
        end

        it 'emits a telemetry event for the completed build' do
          Timecop.freeze do
            expected_json = {
              'telemetry-source' => 'cloud_controller_ng',
              'telemetry-time' => Time.now.to_datetime.rfc3339,
              'build-completed' => {
                'api-version' => 'internal',
                'lifecycle' => 'buildpack',
                'buildpacks' => %w[the-pleasant-buildpack],
                'stack' => 'cflinuxfs4',
                'app-id' => OpenSSL::Digest::SHA256.hexdigest(staged_app.guid),
                'build-id' => OpenSSL::Digest::SHA256.hexdigest(build.guid)
              }
            }
            expect_any_instance_of(ActiveSupport::Logger).to receive(:info).with(JSON.generate(expected_json))

            allow_any_instance_of(BuildModel).to receive(:in_final_state?).and_return(false)
            post url, MultiJson.dump(staging_response)

            expect(last_response.status).to eq(200), last_response.body
          end
        end

        it 'emits metrics for staging success' do
          one_hour_in_nanoseconds = (1.hour.to_i * 1e9).to_i
          expect(statsd_updater).to receive(:report_staging_success_metrics).with(one_hour_in_nanoseconds)
          expect(prometheus_updater).to receive(:report_staging_success_metrics).with(one_hour_in_nanoseconds)
          Timecop.freeze(Time.now) do
            post url, MultiJson.dump(staging_response)
          end
        end

        it 'propagates api errors from staging_response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(CloudController::Errors::ApiError.new_from_details('JobTimeout'))

          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(524)
          expect(last_response.body).to match(/JobTimeout/)
        end

        it 'propagates other errors from staging_response' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).and_raise(StandardError)

          expect do
            post url, MultiJson.dump(staging_response)
          end.to raise_error(StandardError)
        end

        context 'when staging failed' do
          let(:failure_reason) { 'something went wrong' }
          let(:staging_result_json) { nil }

          it 'passes down the sanitized version of the error to the diego stager' do
            expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), { error: sanitized_failure_reason }, false)

            post url, MultiJson.dump(staging_response)
            expect(last_response.status).to eq(200)
          end

          it 'emits metrics for staging failure' do
            one_hour_in_nanoseconds = (1.hour.to_i * 1e9).to_i
            expect(statsd_updater).to receive(:report_staging_failure_metrics).with(one_hour_in_nanoseconds)
            expect(prometheus_updater).to receive(:report_staging_failure_metrics).with(one_hour_in_nanoseconds)
            Timecop.freeze(Time.now) do
              post url, MultiJson.dump(staging_response)
            end
          end
        end
      end

      context 'when the build does not exist' do
        let(:staging_guid) { 'asdf' }

        it 'returns 404' do
          post url, MultiJson.dump(staging_response)
          expect(last_response.status).to eq(404)
          expect(last_response.body).to match(/Build not found/)
        end
      end

      context 'when the start query param has a true value' do
        it 'requests staging_complete with start' do
          expect_any_instance_of(Diego::Stager).to receive(:staging_complete).with(instance_of(BuildModel), staging_response, true)

          post "#{url}?start=true", MultiJson.dump(staging_response)
          expect(last_response.status).to eq(200)
        end
      end

      describe 'validation' do
        context 'when sending invalid json' do
          it 'fails with a 400' do
            post url, 'this is not json'

            expect(last_response.status).to eq(400)
            expect(last_response.body).to match(/MessageParseError/)
          end
        end
      end
    end
  end
end
