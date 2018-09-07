require 'spec_helper'
require 'logcache/traffic_controller_decorator'
require 'utils/time_utils'

RSpec.describe Logcache::TrafficControllerDecorator do
  subject { described_class.new(wrapped_logcache_client).container_metrics(source_guid: process_guid) }
  let(:wrapped_logcache_client) { instance_double(Logcache::Client, container_metrics: logcache_response) }

  let(:num_instances) { 11 }
  let(:process) { VCAP::CloudController::ProcessModel.make(instances: num_instances) }
  let(:process_guid) { process.guid }
  let(:logcache_response) { Logcache::V1::ReadResponse.new(envelopes: envelopes) }
  let(:envelopes) { Loggregator::V2::EnvelopeBatch.new }

  def generate_batch(size, offset: 0, last_timestamp: TimeUtils.to_nanoseconds(Time.now), cpu_percentage: 100)
    batch = (1..size).to_a.map do |i|
      Loggregator::V2::Envelope.new(
        timestamp: last_timestamp,
        source_id: process_guid,
        gauge: Loggregator::V2::Gauge.new(metrics: {
          'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: cpu_percentage),
          'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 100 * i + 2),
          'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 100 * i + 3),
        }),
        instance_id: (offset + i).to_s
      )
    end
    Loggregator::V2::EnvelopeBatch.new(batch: batch)
  end

  describe 'converting from Logcache to TrafficController' do
    before do
      allow(wrapped_logcache_client).to receive(:container_metrics).and_return(logcache_response)
    end

    it 'retrieves metrics for the correct source guid' do
      subject

      expect(wrapped_logcache_client).to have_received(:container_metrics).with(
        hash_including(source_guid: process_guid)
      )
    end

    context 'when given an empty envelope batch' do
      let(:envelopes) { Loggregator::V2::EnvelopeBatch.new }

      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end

    context 'when given a single envelope back' do
      let(:envelopes) {
        Loggregator::V2::EnvelopeBatch.new(
          batch: [Loggregator::V2::Envelope.new(
            source_id: process_guid,
            gauge: Loggregator::V2::Gauge.new(metrics: {
              'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 10),
              'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 11),
              'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 12),
            }),
            instance_id: '1'
          )]
        )
      }

      it 'returns an array of one envelope, formatted as Traffic Controller would' do
        expect(subject.first.containerMetric.applicationId).to eq(process_guid)
        expect(subject.first.containerMetric.instanceIndex).to eq(1)
        expect(subject.first.containerMetric.cpuPercentage).to eq(10)
        expect(subject.first.containerMetric.memoryBytes).to eq(11)
        expect(subject.first.containerMetric.diskBytes).to eq(12)
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
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
              }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 30),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 31),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 32),
              }),
              instance_id: '3'
            )
          ]
        )
      }
      let(:num_instances) { 3 }

      it 'returns an array of envelopes, formatted as Traffic Controller would' do
        expect(subject.first.containerMetric.applicationId).to eq(process_guid)
        expect(subject.first.containerMetric.instanceIndex).to eq(1)
        expect(subject.first.containerMetric.cpuPercentage).to eq(10)
        expect(subject.first.containerMetric.memoryBytes).to eq(11)
        expect(subject.first.containerMetric.diskBytes).to eq(12)

        expect(subject.second.containerMetric.applicationId).to eq(process_guid)
        expect(subject.second.containerMetric.instanceIndex).to eq(2)
        expect(subject.second.containerMetric.cpuPercentage).to eq(20)
        expect(subject.second.containerMetric.memoryBytes).to eq(21)
        expect(subject.second.containerMetric.diskBytes).to eq(22)

        cm = subject[2].containerMetric
        expect(cm.applicationId).to eq(process_guid)
        expect(cm.instanceIndex).to eq(3)
        expect(cm.cpuPercentage).to eq(30)
        expect(cm.memoryBytes).to eq(31)
        expect(cm.diskBytes).to eq(32)
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
              }),
              instance_id: '1'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 20),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 21),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 22),
              }),
              instance_id: '2'
            ),
            Loggregator::V2::Envelope.new(
              source_id: process_guid,
              gauge: Loggregator::V2::Gauge.new(metrics: {
                'cpu' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 30),
                'memory' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 31),
                'disk' => Loggregator::V2::GaugeValue.new(unit: 'bytes', value: 32),
              }),
              instance_id: '1'
            )
          ]
        )
      }
      let(:num_instances) { 2 }

      it 'returns only the newest metric' do
        expect(subject.count).to eq(2)
        expect(subject.first.containerMetric.instanceIndex).to eq(1)
        expect(subject.first.containerMetric.cpuPercentage).to eq(10)
        expect(subject.second.containerMetric.instanceIndex).to eq(2)
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

          expect(subject.first.containerMetric.instanceIndex).to eq(1)
          expect(subject.first.containerMetric.cpuPercentage).to eq(34.0)
        end
      end
    end

    describe 'walking the log cache' do
      let(:lookback_window) { 2.minutes }

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
