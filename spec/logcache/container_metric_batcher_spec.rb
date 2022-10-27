require 'spec_helper'
require 'logcache/container_metric_batcher'
require 'utils/time_utils'

RSpec.describe Logcache::ContainerMetricBatcher do
  subject { described_class.new(wrapped_logcache_client).container_metrics(source_guid: process_guid, logcache_filter: filter) }
  let(:wrapped_logcache_client) { instance_double(Logcache::Client, container_metrics: logcache_response) }

  let(:num_instances) { 11 }
  let(:process) { VCAP::CloudController::ProcessModel.make(instances: num_instances) }
  let(:process_guid) { process.guid }
  let(:logcache_response) { Logcache::V1::ReadResponse.new(envelopes: envelopes) }
  let(:envelopes) { Loggregator::V2::EnvelopeBatch.new }

  def generate_batch(size, offset: 0, last_timestamp: TimeUtils.to_nanoseconds(Time.now), cpu_percentage: 100)
    batch = (1..size).to_a.flat_map do |i|
      [
        Loggregator::V2::Envelope.new(
          timestamp: last_timestamp,
          source_id: process_guid,
          gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: cpu_percentage),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 100 * i + 2),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 100 * i + 3),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 100 * i + 4),
            }),
          instance_id: (offset + i).to_s,
        ),
        Loggregator::V2::Envelope.new(
          timestamp: last_timestamp,
          source_id: process_guid,
          gauge: Loggregator::V2::Gauge.new(metrics: {
              'absolute_usage' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 100 * i + 1),
              'absolute_entitlement' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 100 * i + 2),
              'container_age' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 100 * i + 3),
          }),
          instance_id: (offset + i).to_s,
        )
      ]
    end
    Loggregator::V2::EnvelopeBatch.new(batch: batch)
  end

  describe 'batches envelopes' do
    let(:filter) { ->(_) { true } }

    before do
      allow(wrapped_logcache_client).to receive(:container_metrics).and_return(logcache_response)
    end

    it 'retrieves metrics for the correct source guid' do
      subject

      expect(wrapped_logcache_client).to have_received(:container_metrics).with(
        hash_including(source_guid: process_guid)
      )
    end

    context 'filters' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 13),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 13),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
              }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 9),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 8),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 7),
              }),
              instance_id: '1'
          ),
          ]
        )
      }
      let(:filter) { ->(e) { e.gauge.metrics['cpu'].value == 10 } }

      it 'filters envelopes' do
        subject

        expect(subject).to have(1).items
        expect(subject.first.instance_index).to eq(1)
        expect(subject.first.cpu_percentage).to eq(10)
        expect(subject.first.memory_bytes).to eq(11)
        expect(subject.first.disk_bytes).to eq(12)
        expect(subject.first.log_rate).to eq(13)
      end
    end

    context 'when given an empty envelope batch' do
      let(:envelopes) { Loggregator::V2::EnvelopeBatch.new }

      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when given a mixture of expected metrics envelopes and others' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'absolute_usage' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 300),
                  'absolute_entitlement' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 400),
                  'container_age' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 500),
              }),
              instance_id: '1'
              ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                    'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                    'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
                    'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
                    'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 13),
                }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'absolute_usage' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 600),
                  'absolute_entitlement' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 700),
                  'container_age' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 800),
              }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                    'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                    'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                    'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
                    'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 23),
                }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'absolute_usage' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 900),
                  'absolute_entitlement' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 1000),
                  'container_age' => Loggregator::V2::GaugeValue.new(unit: 'nanoseconds', value: 1100),
              }),
              instance_id: '3'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                    'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 30),
                    'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 31),
                    'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 32),
                    'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 33),
                }),
              instance_id: '3'
            )
          ]
        )
      }
      let(:num_instances) { 3 }

      it 'returns an array of batched metrics' do
        expect(subject.first.instance_index).to eq(1)
        expect(subject.first.cpu_percentage).to eq(10)
        expect(subject.first.memory_bytes).to eq(11)
        expect(subject.first.disk_bytes).to eq(12)
        expect(subject.first.log_rate).to eq(13)

        expect(subject.second.instance_index).to eq(2)
        expect(subject.second.cpu_percentage).to eq(20)
        expect(subject.second.memory_bytes).to eq(21)
        expect(subject.second.disk_bytes).to eq(22)
        expect(subject.second.log_rate).to eq(23)

        cm = subject[2]
        expect(cm.instance_index).to eq(3)
        expect(cm.cpu_percentage).to eq(30)
        expect(cm.memory_bytes).to eq(31)
        expect(cm.disk_bytes).to eq(32)
        expect(cm.log_rate).to eq(33)
      end
    end

    context 'when given a single envelope back' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [Loggregator::V2::Envelope.new(
            source_id: process_guid,
            gauge: Loggregator::V2::Gauge.new(metrics: {
              'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 0.10),
              'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11.0),
              'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12.0),
              'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 13.0),
              'disk_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 24.0),
              'memory_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 25.0),
              'log_rate_limit' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 26.0),
            }),
            instance_id: '1'
          )]
        )
      }

      it 'returns an array of one batched envelope' do
        expect(subject.first.instance_index).to eql(1)
        expect(subject.first.cpu_percentage).to eql(0.10)
        expect(subject.first.memory_bytes).to eql(11)
        expect(subject.first.disk_bytes).to eql(12)
        expect(subject.first.log_rate).to eql(13)
        expect(subject.first.disk_bytes_quota).to eql(24)
        expect(subject.first.memory_bytes_quota).to eql(25)
        expect(subject.first.log_rate_limit).to eql(26)
      end
    end

    context 'when given multiple envelopes back' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 13),
                'disk_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 24),
                'memory_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 25),
                'log_rate_limit' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 26),
              }),
              instance_id: '1',
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 23),
                'disk_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 34),
                'memory_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 35),
                'log_rate_limit' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 36),
             }),
              instance_id: '2',
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 30),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 31),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 32),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 33),
                'disk_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 44),
                'memory_quota' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 45),
                'log_rate_limit' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 46),
            }),
              instance_id: '3',
            )
          ]
        )
      }
      let(:num_instances) { 3 }

      it 'returns an array of batched metrics' do
        expect(subject.first.instance_index).to eq(1)
        expect(subject.first.cpu_percentage).to eq(10)
        expect(subject.first.memory_bytes).to eq(11)
        expect(subject.first.disk_bytes).to eq(12)
        expect(subject.first.log_rate).to eq(13)
        expect(subject.first.disk_bytes_quota).to eq(24)
        expect(subject.first.memory_bytes_quota).to eq(25)
        expect(subject.first.log_rate_limit).to eq(26)

        expect(subject.second.instance_index).to eq(2)
        expect(subject.second.cpu_percentage).to eq(20)
        expect(subject.second.memory_bytes).to eq(21)
        expect(subject.second.disk_bytes).to eq(22)
        expect(subject.second.log_rate).to eq(23)
        expect(subject.second.disk_bytes_quota).to eq(34)
        expect(subject.second.memory_bytes_quota).to eq(35)
        expect(subject.second.log_rate_limit).to eq(36)

        cm = subject[2]
        expect(cm.instance_index).to eq(3)
        expect(cm.cpu_percentage).to eq(30)
        expect(cm.memory_bytes).to eq(31)
        expect(cm.disk_bytes).to eq(32)
        expect(cm.log_rate).to eq(33)
        expect(cm.disk_bytes_quota).to eq(44)
        expect(cm.memory_bytes_quota).to eq(45)
        expect(cm.log_rate_limit).to eq(46)
      end
    end

    context 'when given multiple metrics for the same instance' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 13),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 23),
              }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 30),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 31),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 32),
                'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 33),
              }),
              instance_id: '1'
            )
          ]
        )
      }
      let(:num_instances) { 2 }

      it 'returns only the newest metric' do
        expect(subject.count).to eq(2)
        expect(subject.first.instance_index).to eq(1)
        expect(subject.first.cpu_percentage).to eq(10)
        expect(subject.second.instance_index).to eq(2)
      end
    end

    context 'when there are envelopes for the same instance id across multiple pages' do
      let(:call_time) { Time.at(1536269249, 784009.985) }
      let(:call_time_ns) { TimeUtils.to_nanoseconds(call_time) }
      let(:last_envelope_time_first_page) { call_time - 1.minute }
      let(:last_envelope_time_first_page_ns) { TimeUtils.to_nanoseconds(last_envelope_time_first_page) }
      let(:last_envelope_time_final_page) { call_time - 1.minute - 30.seconds }
      let(:last_envelope_time_final_page_ns) { TimeUtils.to_nanoseconds(last_envelope_time_final_page) }

      let(:envelopes_max_limit_first_page) { generate_batch(1000, last_timestamp: last_envelope_time_first_page_ns, cpu_percentage: 34) }
      let(:envelopes_under_limit_final_page) { generate_batch(1, last_timestamp: last_envelope_time_final_page_ns, cpu_percentage: 10) }

      let(:logcache_response_max_limit_first_page) { Logcache::V1::ReadResponse.new(envelopes: envelopes_max_limit_first_page) }
      let(:logcache_response_under_limit_final_page) { Logcache::V1::ReadResponse.new(envelopes: envelopes_under_limit_final_page) }

      before do
        responses = [logcache_response_max_limit_first_page, logcache_response_under_limit_final_page]
        allow(wrapped_logcache_client).to receive(:container_metrics).and_return(*responses)
      end

      it 'only returns the most recent envelope for that instance' do
        Timecop.freeze(call_time) do
          expect(subject).to have(1000).items

          expect(subject.first.instance_index).to eq(1)
          expect(subject.first.cpu_percentage).to eq(34.0)
        end
      end
    end

    context 'when given container metrics in separate envelopes' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 13),
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                  'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                  'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                  'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
                  'log_rate' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 23),
              }),
              instance_id: '2'
            )
          ]
        )
      }
      let(:num_instances) { 2 }

      it 'returns a single envelope per instance' do
        expect(subject.count).to eq(2)

        expect(subject.first.instance_index).to eq(1)
        expect(subject.first.cpu_percentage).to eq(10)
        expect(subject.first.memory_bytes).to eq(11)
        expect(subject.first.disk_bytes).to eq(12)
        expect(subject.first.log_rate).to eq(13)

        expect(subject.second.instance_index).to eq(2)
        expect(subject.second.cpu_percentage).to eq(20)
        expect(subject.second.memory_bytes).to eq(21)
        expect(subject.second.disk_bytes).to eq(22)
        expect(subject.second.log_rate).to eq(23)
      end
    end

    describe 'walking the log cache' do
      let(:lookback_window) { 2.minutes }

      context 'when log cache never stops returning results' do
        let(:envelopes_max_limit_first_page) { generate_batch(1000) }

        let(:logcache_response_max_limit_first_page) { Logcache::V1::ReadResponse.new(envelopes: envelopes_max_limit_first_page) }

        before do
          allow(wrapped_logcache_client).to receive(:container_metrics).and_return(logcache_response_max_limit_first_page)
        end

        it 'stops requesting additional pages of metrics after 100 calls' do
          subject

          expect(wrapped_logcache_client).to have_received(:container_metrics).exactly(100).times
        end
      end

      context 'when the log cache has fewer than 1000 envelopes for the time window' do
        let(:envelopes) { generate_batch(999) }

        it 'returns with all the metrics' do
          expect(subject).to have(999).items
        end

        it 'requests envelopes from the last two minutes' do
          Timecop.freeze do
            subject

            start_time = TimeUtils.to_nanoseconds((Time.now - lookback_window))
            end_time = TimeUtils.to_nanoseconds(Time.now)
            expect(wrapped_logcache_client).to have_received(:container_metrics).
              with(hash_including(start_time: start_time, end_time: end_time))
          end
        end
      end

      context 'when log cache has more than 1000 envelopes for the time window' do
        let(:call_time) { Time.at(1536269249, 784009.985) }
        let(:call_time_ns) { TimeUtils.to_nanoseconds(call_time) }
        let(:last_envelope_time_first_page) { call_time - 1.minute }
        let(:last_envelope_time_first_page_ns) { TimeUtils.to_nanoseconds(last_envelope_time_first_page) }
        let(:last_envelope_time_second_page) { call_time - 1.minute - 30.seconds }
        let(:last_envelope_time_second_page_ns) { TimeUtils.to_nanoseconds(last_envelope_time_second_page) }

        let(:envelopes_max_limit_first_page) { generate_batch(1000, offset: 0, last_timestamp: last_envelope_time_first_page_ns) }
        let(:envelopes_max_limit_second_page) { generate_batch(1000, offset: 1000, last_timestamp: last_envelope_time_second_page_ns) }
        let(:envelopes_under_limit_final_page) { generate_batch(1, offset: 2000) }

        let(:logcache_response_max_limit_first_page) { Logcache::V1::ReadResponse.new(envelopes: envelopes_max_limit_first_page) }
        let(:logcache_response_max_limit_second_page) { Logcache::V1::ReadResponse.new(envelopes: envelopes_max_limit_second_page) }
        let(:logcache_response_under_limit_final_page) { Logcache::V1::ReadResponse.new(envelopes: envelopes_under_limit_final_page) }

        before do
          responses = [logcache_response_max_limit_first_page, logcache_response_max_limit_second_page, logcache_response_under_limit_final_page]
          allow(wrapped_logcache_client).to receive(:container_metrics).and_return(*responses)
        end

        it 'iterates, using the last envelopes timestamp to narrow the window, until it hits a page with < 1000 envelopes' do
          Timecop.freeze(call_time) do
            expect(subject).to have(2001).items

            start_time = TimeUtils.to_nanoseconds((call_time - lookback_window))
            expect(wrapped_logcache_client).to have_received(:container_metrics).
              with(hash_including(start_time: start_time, end_time: call_time_ns))

            expect(wrapped_logcache_client).to have_received(:container_metrics).
              with(hash_including(start_time: start_time, end_time: last_envelope_time_first_page_ns - 1))

            expect(wrapped_logcache_client).to have_received(:container_metrics).
              with(hash_including(start_time: start_time, end_time: last_envelope_time_second_page_ns - 1))
          end
        end
      end
    end
  end
end
