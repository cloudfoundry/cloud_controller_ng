require 'spec_helper'
require 'cloud_controller/diego/reporters/instances_stats_reporter'

module VCAP::CloudController
  module Diego
    RSpec.describe InstancesStatsReporter do
      subject(:instances_reporter) { InstancesStatsReporter.new(bbs_instances_client, log_cache_client) }
      let(:app) { AppModel.make }
      let(:process) { ProcessModel.make(instances: desired_instances, app: app, state: ProcessModel::STARTED) }
      let(:desired_instances) { 1 }
      let(:bbs_instances_client) { instance_double(BbsInstancesClient) }
      let(:log_cache_client) { instance_double(Logcache::ContainerMetricBatcher) }

      let(:two_days_ago_since_epoch_ns) { 2.days.ago.to_f * 1e9 }
      let(:two_days_in_seconds) { 60 * 60 * 24 * 2 }
      let(:is_routable) { true }

      def make_actual_lrp(instance_guid:, index:, state:, error:, since:)
        lrp = ::Diego::Bbs::Models::ActualLRP.new(
          actual_lrp_key: ::Diego::Bbs::Models::ActualLRPKey.new(index:),
          actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid:),
          state: state,
          placement_error: error,
          since: since
        )
        lrp.routable = is_routable unless is_routable.nil?
        lrp
      end

      before { Timecop.freeze(Time.at(1.day.ago.to_i)) }
      after { Timecop.return }

      describe '#stats_for_app' do
        let(:desired_instances) { bbs_actual_lrps_response.length }
        let(:bbs_actual_lrps_response) { [actual_lrp_1] }
        let(:bbs_desired_lrp_response) do
          ::Diego::Bbs::Models::DesiredLRP.new(
            PlacementTags: placement_tags,
            metric_tags: metrics_tags
          )
        end
        let(:placement_tags) { ['isolation-segment-name'] }
        let(:metrics_tags) do
          {
            'source_id' => ::Diego::Bbs::Models::MetricTagValue.new(static: process.app.guid),
            'process_id' => ::Diego::Bbs::Models::MetricTagValue.new(static: process.guid)
          }
        end
        let(:formatted_current_time) { Time.now.to_datetime.rfc3339 }

        let(:lrp_1_net_info) do
          ::Diego::Bbs::Models::ActualLRPNetInfo.new(
            address: 'lrp-host',
            ports: [
              ::Diego::Bbs::Models::PortMapping.new(container_port: DEFAULT_APP_PORT, host_port: 2222),
              ::Diego::Bbs::Models::PortMapping.new(container_port: 1111)
            ]
          )
        end
        let(:actual_lrp_1) do
          make_actual_lrp(
            instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: 'some-details', since: two_days_ago_since_epoch_ns
          ).tap do |actual_lrp|
            actual_lrp.actual_lrp_net_info = lrp_1_net_info
          end
        end
        let(:log_cache_response) do
          container_metric_batch = ::Logcache::ContainerMetricBatch.new
          container_metric_batch.instance_index = 0
          container_metric_batch.cpu_percentage = 3.92
          container_metric_batch.cpu_entitlement_percentage = 80.0
          container_metric_batch.memory_bytes = 564
          container_metric_batch.disk_bytes = 5000
          container_metric_batch.memory_bytes_quota = 1234
          container_metric_batch.disk_bytes_quota = 10_234
          container_metric_batch.log_rate = 5
          container_metric_batch.log_rate_limit = 10
          [container_metric_batch]
        end

        let(:expected_lrp_1_net_info) do
          {
            address: 'lrp-host',
            instance_address: '',
            ports: [
              { container_port: DEFAULT_APP_PORT, container_tls_proxy_port: 0, host_port: 2222, host_tls_proxy_port: 0 },
              { container_port: 1111, container_tls_proxy_port: 0, host_port: 0, host_tls_proxy_port: 0 }
            ],
            preferred_address: :UNKNOWN
          }
        end
        let(:expected_stats_response) do
          {
            0 => {
              state: 'RUNNING',
              routable: is_routable,
              isolation_segment: 'isolation-segment-name',
              stats: {
                name: process.name,
                uris: process.uris,
                host: 'lrp-host',
                instance_guid: 'instance-a',
                port: 2222,
                net_info: expected_lrp_1_net_info,
                uptime: two_days_in_seconds,
                mem_quota: 1234,
                disk_quota: 10_234,
                log_rate_limit: 10,
                fds_quota: process.file_descriptors,
                usage: {
                  time: formatted_current_time,
                  cpu: 0.0392,
                  cpu_entitlement: 0.8,
                  mem: 564,
                  disk: 5000,
                  log_rate: 5
                }
              },
              details: 'some-details'
            }
          }
        end

        before do
          allow(bbs_instances_client).to receive_messages(lrp_instances: bbs_actual_lrps_response, desired_lrp_instance: bbs_desired_lrp_response)
          allow(log_cache_client).to receive(:container_metrics).
            with(source_guid: process.app.guid, logcache_filter: anything).
            and_return(log_cache_response)
        end

        it 'returns a map of stats & states per index in the correct units' do
          expect(instances_reporter.stats_for_app(process)).to eq([expected_stats_response, []])
        end

        context 'when there are multiple lrps with different states' do
          let(:bbs_actual_lrps_response) { [actual_lrp_1, actual_lrp_2] }
          let(:actual_lrp_1) do
            make_actual_lrp(
              instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: 'some-details', since: two_days_ago_since_epoch_ns
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end
          let(:actual_lrp_2) do
            make_actual_lrp(
              instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: 'some-details', since: two_days_ago_since_epoch_ns
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end

          before do
            allow(bbs_instances_client).to receive_messages(lrp_instances: bbs_actual_lrps_response, desired_lrp_instance: bbs_desired_lrp_response)
          end

          it 'shows all correct state for all instances' do
            result, = instances_reporter.stats_for_app(process)
            expect(result[0][:state]).to eq('RUNNING')
            expect(result[1][:state]).to eq('STARTING')
          end
        end

        context 'when there are multiple lrps with the same index' do
          let(:desired_instances) { 3 }
          let(:bbs_actual_lrps_response) { [actual_lrp_1, actual_lrp_2, actual_lrp_3, actual_lrp_4, actual_lrp_5] }
          let(:actual_lrp_1) do
            make_actual_lrp(
              instance_guid: '', index: 0, state: ::Diego::ActualLRPState::UNCLAIMED, error: 'some-details', since: two_days_ago_since_epoch_ns
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end
          let(:actual_lrp_2) do
            make_actual_lrp(
              instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: 'some-details', since: two_days_ago_since_epoch_ns - 1000
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end

          let(:actual_lrp_3) do
            make_actual_lrp(
              instance_guid: '', index: 1, state: ::Diego::ActualLRPState::UNCLAIMED, error: 'some-details', since: two_days_ago_since_epoch_ns
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end

          let(:actual_lrp_4) do
            make_actual_lrp(
              instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: 'some-details', since: two_days_ago_since_epoch_ns - 1000
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end

          let(:actual_lrp_5) do
            make_actual_lrp(
              instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::RUNNING, error: 'some-details', since: two_days_ago_since_epoch_ns
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end

          before do
            allow(bbs_instances_client).to receive_messages(lrp_instances: bbs_actual_lrps_response, desired_lrp_instance: bbs_desired_lrp_response)
          end

          it 'shows all correct state for all instances' do
            result, = instances_reporter.stats_for_app(process)
            expect(result.length).to eq(3)
            expect(result[0][:state]).to eq('DOWN')
            expect(result[1][:state]).to eq('DOWN')
            expect(result[2][:state]).to eq('RUNNING')
          end
        end

        context 'when a NoRunningInstances error is thrown for desired_lrp and it exists an actual_lrp' do
          let(:error) { CloudController::Errors::NoRunningInstances.new('No running instances ruh roh') }
          let(:expected_stopping_response) do
            {
              0 => {
                state: 'STOPPING',
                routable: is_routable,
                stats: {
                  name: process.name,
                  uris: process.uris,
                  host: 'lrp-host',
                  instance_guid: 'instance-a',
                  port: 2222,
                  net_info: expected_lrp_1_net_info,
                  uptime: two_days_in_seconds,
                  mem_quota: nil,
                  disk_quota: nil,
                  log_rate_limit: nil,
                  fds_quota: process.file_descriptors,
                  usage: {}
                },
                details: 'some-details'
              }
            }
          end
          let(:bbs_actual_lrps_response) { [actual_lrp_1] }
          let(:lrp_1_net_info) do
            ::Diego::Bbs::Models::ActualLRPNetInfo.new(
              address: 'lrp-host',
              ports: [
                ::Diego::Bbs::Models::PortMapping.new(container_port: DEFAULT_APP_PORT, host_port: 2222),
                ::Diego::Bbs::Models::PortMapping.new(container_port: 1111)
              ]
            )
          end
          let(:actual_lrp_1) do
            make_actual_lrp(
              instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: 'some-details', since: two_days_ago_since_epoch_ns
            ).tap do |actual_lrp|
              actual_lrp.actual_lrp_net_info = lrp_1_net_info
            end
          end

          before do
            allow(bbs_instances_client).to receive_messages(lrp_instances: bbs_actual_lrps_response)
            allow(bbs_instances_client).to receive(:desired_lrp_instance).with(process).and_raise(error)
          end

          it 'shows all instances as "STOPPING" state' do
            expect(instances_reporter.stats_for_app(process)).to eq([expected_stopping_response, []])
          end

          context 'when "app_instance_stopping_state" is false' do
            before do
              TestConfig.override(app_instance_stopping_state: false)
            end

            let(:expected_down_response) do
              {
                0 => {
                  state: 'DOWN',
                  routable: is_routable,
                  stats: {
                    name: process.name,
                    uris: process.uris,
                    host: 'lrp-host',
                    instance_guid: 'instance-a',
                    port: 2222,
                    net_info: expected_lrp_1_net_info,
                    uptime: two_days_in_seconds,
                    mem_quota: nil,
                    disk_quota: nil,
                    log_rate_limit: nil,
                    fds_quota: process.file_descriptors,
                    usage: {}
                  },
                  details: 'some-details'
                }
              }
            end

            it 'shows all instances as "DOWN" state' do
              expect(instances_reporter.stats_for_app(process)).to eq([expected_down_response, []])
            end
          end
        end

        context 'when a NoRunningInstances error is thrown for desired_lrp and it does not exist an actual_lrp' do
          let(:error) { CloudController::Errors::NoRunningInstances.new('No running instances ruh roh') }
          let(:expected_stats_response) do
            {
              0 => {
                state: 'DOWN',
                stats: {
                  uptime: 0
                }
              }
            }
          end

          before do
            allow(bbs_instances_client).to receive(:lrp_instances).with(process).and_raise(error)
            allow(bbs_instances_client).to receive(:desired_lrp_instance).with(process).and_raise(error)
          end

          it 'shows all instances as "DOWN" state' do
            expect(instances_reporter.stats_for_app(process)).to eq([expected_stats_response, []])
          end
        end

        context 'when process is not routable' do
          let(:is_routable) { false }

          it 'sets the routable property to false' do
            response, = instances_reporter.stats_for_app(process)
            expect(response[0][:routable]).to be(false)
          end
        end

        context 'when diego does not send the routable property' do
          let(:is_routable) { nil }

          it 'does not include the routable property in stats' do
            response, = instances_reporter.stats_for_app(process)
            expect(response[0]).to have_key(:routable)
            expect(response[0][:routable]).to be_nil
          end
        end

        it 'passes a process_id filter' do
          filter = nil

          allow(log_cache_client).to receive(:container_metrics) { |args|
            filter = args[:logcache_filter]
          }.and_return(log_cache_response)

          expected_envelope = Loggregator::V2::Envelope.new(
            source_id: process.app.guid,
            gauge: Loggregator::V2::Gauge.new(metrics: {
                                                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'percentage', value: 10),
                                                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
                                                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12)
                                              }),
            instance_id: '1',
            tags: {
              'process_id' => process.guid
            }
          )
          other_envelope = Loggregator::V2::Envelope.new(
            source_id: process.app.guid,
            gauge: Loggregator::V2::Gauge.new(metrics: {
                                                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'percentage', value: 13),
                                                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                                                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10)
                                              }),
            instance_id: '1',
            tags: {
              'process_id' => 'different-guid'
            }
          )

          instances_reporter.stats_for_app(process)

          expect([expected_envelope, other_envelope].select { |e| filter.call(e) }).to eq([expected_envelope])
        end

        context 'when the desired lrp does NOT have a process_id metric tag' do
          let(:metrics_tags) do
            {
              'source_id' => ::Diego::Bbs::Models::MetricTagValue.new(static: process.guid)
            }
          end
          let(:log_cache_response) do
            container_metric_batch = ::Logcache::ContainerMetricBatch.new
            container_metric_batch.instance_index = 0
            container_metric_batch.cpu_percentage = 3.92
            container_metric_batch.cpu_entitlement_percentage = 80.0
            container_metric_batch.memory_bytes = 564
            container_metric_batch.disk_bytes = 5000
            container_metric_batch.log_rate = 5
            container_metric_batch.memory_bytes_quota = 1234
            container_metric_batch.disk_bytes_quota = 10_234
            container_metric_batch.log_rate_limit = 10
            [container_metric_batch]
          end

          it 'gets metrics for the process and does not filter on the source_id' do
            expect(log_cache_client).
              to receive(:container_metrics).
              with(source_guid: process.guid, logcache_filter: anything).
              and_return(log_cache_response)

            expect(instances_reporter.stats_for_app(process)).to eq([expected_stats_response, []])
          end
        end

        context 'when there is no isolation segment for the app' do
          let(:placement_tags) { [] }

          it 'returns nil for the isolation_segment' do
            expect(instances_reporter.stats_for_app(process)[0][:isolation_segment]).to be_nil
          end
        end

        context 'when the default port could not be found' do
          let(:lrp_1_net_info) do
            ::Diego::Bbs::Models::ActualLRPNetInfo.new(
              address: 'lrp-host',
              ports: [
                ::Diego::Bbs::Models::PortMapping.new(container_port: 1111),
                ::Diego::Bbs::Models::PortMapping.new(container_port: 2222)
              ]
            )
          end

          it 'sets "port" to 0' do
            result, = instances_reporter.stats_for_app(process)

            expect(result[0][:stats][:port]).to eq(0)
          end
        end

        context 'when log cache somehow returns a partial response without cpu_percentage' do
          # We aren't exactly sure how this happens, but it can happen on an overloaded deployment, see #156707836
          let(:log_cache_response) do
            container_metric_batch = ::Logcache::ContainerMetricBatch.new
            container_metric_batch.instance_index = 0
            container_metric_batch.memory_bytes = 564
            [container_metric_batch]
          end

          it 'sets all the stats to zero' do
            result, = instances_reporter.stats_for_app(process)
            expect(result[0][:stats][:usage]).to eq({
                                                      time: formatted_current_time,
                                                      cpu: 0,
                                                      cpu_entitlement: 0,
                                                      mem: 0,
                                                      disk: 0,
                                                      log_rate: 0
                                                    })
          end
        end

        context 'when log cache returns a response without cpu_entitlement' do
          let(:log_cache_response) do
            container_metric_batch = ::Logcache::ContainerMetricBatch.new
            container_metric_batch.instance_index = 0
            container_metric_batch.cpu_percentage = 3.92
            container_metric_batch.memory_bytes = 564
            container_metric_batch.disk_bytes = 5_000
            container_metric_batch.memory_bytes_quota = 1_234
            container_metric_batch.disk_bytes_quota = 10_234
            container_metric_batch.log_rate = 5
            container_metric_batch.log_rate_limit = 10
            [container_metric_batch]
          end

          it 'sets cpu_entitlement to nil while passing through other metrics' do
            result, = instances_reporter.stats_for_app(process)
            expect(result[0][:stats][:usage]).to eq({
                                                      time: formatted_current_time,
                                                      cpu: 0.0392,
                                                      cpu_entitlement: nil,
                                                      mem: 564,
                                                      disk: 5000,
                                                      log_rate: 5
                                                    })
          end
        end

        context 'when a NoRunningInstances error is thrown for actual_lrp and it exists a desired_lrp' do
          let(:error) { CloudController::Errors::NoRunningInstances.new('No running instances ruh roh') }
          let(:expected_stats_response) do
            {
              0 => {
                state: 'DOWN',
                stats: {
                  uptime: 0
                }
              }
            }
          end
          let(:bbs_desired_lrp_response) do
            ::Diego::Bbs::Models::DesiredLRP.new(
              PlacementTags: placement_tags,
              metric_tags: metrics_tags
            )
          end

          before do
            allow(bbs_instances_client).to receive(:lrp_instances).with(process).and_raise(error)
            allow(bbs_instances_client).to receive_messages(desired_lrp_instance: bbs_desired_lrp_response)
          end

          it 'shows all instances as "DOWN"' do
            expect(instances_reporter.stats_for_app(process)).to eq([expected_stats_response, []])
          end
        end

        context 'when a LogcacheTimeoutReached is thrown' do
          let(:error) { CloudController::Errors::ApiError.new_from_details('ServiceUnavailable', 'Connection to Log Cache timed out') }
          let(:mock_logger) { double(:logger, error: nil, debug: nil) }
          let(:expected_stats_response) do
            {
              0 => {
                state: 'RUNNING',
                routable: true,
                isolation_segment: 'isolation-segment-name',
                stats: {
                  name: process.name,
                  uris: process.uris,
                  host: 'lrp-host',
                  instance_guid: 'instance-a',
                  port: 2222,
                  net_info: expected_lrp_1_net_info,
                  uptime: two_days_in_seconds,
                  mem_quota: nil,
                  disk_quota: nil,
                  log_rate_limit: nil,
                  fds_quota: process.file_descriptors,
                  usage: {}
                },
                details: 'some-details'
              }
            }
          end

          before do
            allow(log_cache_client).to receive(:container_metrics).and_raise(error)
            allow(instances_reporter).to receive(:logger).and_return(mock_logger)
          end

          it 'returns a partial response and a warning' do
            expect(instances_reporter.stats_for_app(process)).to eq([expected_stats_response, ['Stats server temporarily unavailable.']])
          end
        end

        context 'client data mismatch' do
          context 'when number of actual lrps < desired number of instances' do
            let(:bbs_actual_lrps_response) { [] }
            let(:desired_instances) { 1 }
            let(:expected_stats_response) do
              {
                0 => {
                  state: 'DOWN',
                  stats: {
                    uptime: 0
                  }
                }
              }
            end

            it 'provides defaults for unreported instances' do
              expect(instances_reporter.stats_for_app(process)).to eq([expected_stats_response, []])
            end
          end

          context 'when number of actual lrps > desired number of instances' do
            let(:desired_instances) { 0 }
            let(:log_cache_response) { [] }

            it 'ignores superfluous instances' do
              expect(instances_reporter.stats_for_app(process)).to eq([{}, []])
            end
          end

          context 'when number of container metrics < desired number of instances' do
            let(:log_cache_response) { [] }

            it 'provides defaults for unreported instances' do
              result, = instances_reporter.stats_for_app(process)

              expect(result[0][:stats][:usage]).to eq({
                                                        time: formatted_current_time,
                                                        cpu: 0,
                                                        cpu_entitlement: 0,
                                                        mem: 0,
                                                        disk: 0,
                                                        log_rate: 0
                                                      })
            end
          end

          context 'when an error is raised communicating with diego' do
            let(:error) { StandardError.new('tomato') }

            before do
              allow(bbs_instances_client).to receive(:lrp_instances).with(process).and_raise(error)
            end

            it 'raises an InstancesUnavailable exception' do
              expect { instances_reporter.stats_for_app(process) }.to raise_error(CloudController::Errors::InstancesUnavailable, /tomato/)
            end

            context 'when the error is InstancesUnavailable' do
              let(:error) { CloudController::Errors::InstancesUnavailable.new('ruh roh') }
              let(:mock_logger) { double(:logger, error: nil, debug: nil) }

              before { allow(instances_reporter).to receive(:logger).and_return(mock_logger) }

              it 'reraises the exception and logs the error' do
                expect { instances_reporter.stats_for_app(process) }.to raise_error(CloudController::Errors::InstancesUnavailable, /ruh roh/)
                expect(mock_logger).to have_received(:error).with('stats_for_app.error', { error: 'ruh roh' }).once
              end
            end
          end

          context 'when an error is raised communicating with log cache' do
            let(:error) { StandardError.new('tomato') }
            let(:mock_logger) { double(:logger, error: nil, debug: nil) }

            before do
              allow(log_cache_client).to receive(:container_metrics).
                with(source_guid: process.app.guid, logcache_filter: anything).
                and_raise(error)
              allow(instances_reporter).to receive(:logger).and_return(mock_logger)
            end

            it 'raises an InstancesUnavailable exception and logs the error' do
              expect { instances_reporter.stats_for_app(process) }.to raise_error(CloudController::Errors::InstancesUnavailable, /tomato/)
              expect(mock_logger).to have_received(:error).with('stats_for_app.error', { error: 'tomato' }).once
            end

            context 'when the error is InstancesUnavailable' do
              let(:error) { CloudController::Errors::InstancesUnavailable.new('ruh roh') }

              it 'reraises the exception' do
                expect { instances_reporter.stats_for_app(process) }.to raise_error(CloudController::Errors::InstancesUnavailable, /ruh roh/)
              end
            end
          end
        end

        context 'when there is an error fetching metrics envelopes' do
          let(:error) { CloudController::Errors::ApiError.new_from_details('ServiceUnavailable', 'no metrics for you') }
          let(:mock_logger) { double(:logger, error: nil, debug: nil) }
          let(:expected_stats_response) do
            {
              0 => {
                state: 'RUNNING',
                routable: true,
                isolation_segment: 'isolation-segment-name',
                stats: {
                  name: process.name,
                  uris: process.uris,
                  host: 'lrp-host',
                  instance_guid: 'instance-a',
                  port: 2222,
                  net_info: expected_lrp_1_net_info,
                  uptime: two_days_in_seconds,
                  mem_quota: nil,
                  disk_quota: nil,
                  log_rate_limit: nil,
                  fds_quota: process.file_descriptors,
                  usage: {}
                },
                details: 'some-details'
              }
            }
          end

          before do
            allow(log_cache_client).to receive(:container_metrics).
              with(source_guid: process.app.guid, logcache_filter: anything).
              and_raise(error)
            allow(instances_reporter).to receive(:logger).and_return(mock_logger)
          end

          it 'logs, omits metrics-driven fields, and provides a warning' do
            expect(instances_reporter.stats_for_app(process)).to eq([expected_stats_response, ['Stats server temporarily unavailable.']])
            expect(mock_logger).to have_received(:error).with(
              'stats_for_app.error', { error: 'no metrics for you', backtrace: error.backtrace.join($INPUT_RECORD_SEPARATOR) }
            ).once
          end
        end
      end

      describe '#instances_for_processes' do
        let(:second_in_ns) { 1_000_000_000 }
        let(:actual_lrp_0) do
          ::Diego::Bbs::Models::ActualLRP.new(
            actual_lrp_key: ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: process.guid + 'version', index: 0),
            actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-a'),
            state: ::Diego::ActualLRPState::RUNNING,
            placement_error: '',
            since: two_days_ago_since_epoch_ns
          )
        end
        let(:actual_lrp_1) do
          ::Diego::Bbs::Models::ActualLRP.new(
            actual_lrp_key: ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: process.guid + 'version', index: 1),
            actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-b'),
            state: ::Diego::ActualLRPState::CLAIMED,
            placement_error: '',
            since: two_days_ago_since_epoch_ns + (1 * second_in_ns)
          )
        end
        let(:actual_lrp_2a) do
          ::Diego::Bbs::Models::ActualLRP.new(
            actual_lrp_key: ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: process.guid + 'version', index: 2),
            actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-c'),
            state: ::Diego::ActualLRPState::RUNNING,
            placement_error: '',
            since: two_days_ago_since_epoch_ns + (2 * second_in_ns)
          )
        end
        let(:actual_lrp_2b) do
          ::Diego::Bbs::Models::ActualLRP.new(
            actual_lrp_key: ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: process.guid + 'version', index: 2),
            actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-d'),
            state: ::Diego::ActualLRPState::UNCLAIMED,
            placement_error: '',
            since: two_days_ago_since_epoch_ns + (3 * second_in_ns)
          )
        end

        before do
          allow(bbs_instances_client).to receive_messages(actual_lrps_by_processes: bbs_actual_lrps_response)
        end

        context 'with multiple actual lrps' do
          let(:bbs_actual_lrps_response) { [actual_lrp_1, actual_lrp_0, actual_lrp_2a] } # unordered to test sorting by index

          it 'returns all instances sorted by index' do
            instances = subject.instances_for_processes([process])
            expect(instances).to eq({
                                      process.guid => {
                                        0 => { state: 'RUNNING', since: two_days_in_seconds },
                                        1 => { state: 'STARTING', since: two_days_in_seconds - 1 },
                                        2 => { state: 'RUNNING', since: two_days_in_seconds - 2 }
                                      }
                                    })
          end

          context 'when the process is in state STOPPED' do
            before { process.update(state: ProcessModel::STOPPED) }

            it 'returns all instances as STOPPING' do
              instances = subject.instances_for_processes([process])
              expect(instances).to eq({
                                        process.guid => {
                                          0 => { state: 'STOPPING' },
                                          1 => { state: 'STOPPING' },
                                          2 => { state: 'STOPPING' }
                                        }
                                      })
            end
          end
        end

        context 'with multiple actual lrps for the same index' do
          let(:bbs_actual_lrps_response) { [actual_lrp_0, actual_lrp_1, actual_lrp_2a, actual_lrp_2b] }

          it 'returns the newest instance per index' do
            instances = subject.instances_for_processes([process])
            expect(instances).to eq({
                                      process.guid => {
                                        0 => { state: 'RUNNING', since: two_days_in_seconds },
                                        1 => { state: 'STARTING', since: two_days_in_seconds - 1 },
                                        2 => { state: 'STARTING', since: two_days_in_seconds - 3 }
                                      }
                                    })
          end
        end

        context 'with number of desired instances being greater than number of actual lrps' do
          let(:bbs_actual_lrps_response) { [actual_lrp_0, actual_lrp_1] }
          let(:desired_instances) { 4 }

          it 'fills in missing instances as DOWN' do
            instances = subject.instances_for_processes([process])
            expect(instances).to eq({
                                      process.guid => {
                                        0 => { state: 'RUNNING', since: two_days_in_seconds },
                                        1 => { state: 'STARTING', since: two_days_in_seconds - 1 },
                                        2 => { state: 'DOWN' },
                                        3 => { state: 'DOWN' }
                                      }
                                    })
          end
        end

        context 'with multiple processes' do
          let(:second_process) { ProcessModel.make(state: ProcessModel::STARTED) }
          let(:second_process_actual_lrp_0) do
            ::Diego::Bbs::Models::ActualLRP.new(
              actual_lrp_key: ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: second_process.guid + 'version', index: 0),
              actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-e'),
              state: ::Diego::ActualLRPState::RUNNING,
              placement_error: '',
              since: two_days_ago_since_epoch_ns + (4 * second_in_ns)
            )
          end
          let(:second_process_actual_lrp_1) do
            ::Diego::Bbs::Models::ActualLRP.new(
              actual_lrp_key: ::Diego::Bbs::Models::ActualLRPKey.new(process_guid: second_process.guid + 'version', index: 1),
              actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: 'instance-f'),
              state: ::Diego::ActualLRPState::CRASHED,
              placement_error: '',
              since: two_days_ago_since_epoch_ns + (5 * second_in_ns)
            )
          end
          let(:bbs_actual_lrps_response) { [actual_lrp_0, second_process_actual_lrp_0, actual_lrp_1, second_process_actual_lrp_1] } # unordered to test grouping

          it 'returns instances grouped by process guid' do
            instances = subject.instances_for_processes([process, second_process])
            expect(instances).to eq({
                                      process.guid => {
                                        0 => { state: 'RUNNING', since: two_days_in_seconds },
                                        1 => { state: 'STARTING', since: two_days_in_seconds - 1 }
                                      },
                                      second_process.guid => {
                                        0 => { state: 'RUNNING', since: two_days_in_seconds - 4 },
                                        1 => { state: 'CRASHED', since: two_days_in_seconds - 5 }
                                      }
                                    })
          end
        end

        context 'with no actual lrps but desired instances' do
          let(:bbs_actual_lrps_response) { [] }
          let(:desired_instances) { 2 }

          it 'fills in missing instances as DOWN' do
            instances = subject.instances_for_processes([process])
            expect(instances).to eq({
                                      process.guid => {
                                        0 => { state: 'DOWN' },
                                        1 => { state: 'DOWN' }
                                      }
                                    })
          end
        end

        context 'with no actual lrps and no desired instances' do
          let(:bbs_actual_lrps_response) { [] }
          let(:desired_instances) { 0 }

          it 'returns an empty map for the instances' do
            instances = subject.instances_for_processes([process])
            expect(instances).to eq({ process.guid => {} })
          end
        end
      end
    end
  end
end
