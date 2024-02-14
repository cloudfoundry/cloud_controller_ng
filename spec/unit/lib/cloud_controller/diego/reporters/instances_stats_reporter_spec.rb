require 'spec_helper'
require 'cloud_controller/diego/reporters/instances_stats_reporter'

module VCAP::CloudController
  module Diego
    RSpec.describe InstancesStatsReporter do
      subject(:instances_reporter) { InstancesStatsReporter.new(bbs_instances_client, log_cache_client) }
      let(:app) { AppModel.make }
      let(:process) { ProcessModel.make(instances: desired_instances, app: app) }
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
                port: 2222,
                net_info: lrp_1_net_info.to_h,
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

          it 'sets all the stats to their nullish value' do
            result, = instances_reporter.stats_for_app(process)
            expect(result[0][:stats][:usage]).to eq({
                                                      time: formatted_current_time,
                                                      cpu: 0,
                                                      cpu_entitlement: nil,
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

        context 'when a NoRunningInstances error is thrown' do
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
                  port: 2222,
                  net_info: lrp_1_net_info.to_h,
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
                                                        cpu_entitlement: nil,
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
                  port: 2222,
                  net_info: lrp_1_net_info.to_h,
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
    end
  end
end
