require 'spec_helper'
require 'cloud_controller/metrics/request_metrics'

module VCAP::CloudController::Metrics
  RSpec.describe RequestMetrics do
    let(:statsd_client) { double(:statsd_client) }
    let!(:request_metrics) { RequestMetrics.new(statsd_client) } # TODO: probably doesn't need to be a let!, just a let

    describe '#start_request' do
      before do
        allow(statsd_client).to receive(:increment)
        allow(statsd_client).to receive(:gauge)
      end

      it 'increments outstanding requests for statsd' do
        request_metrics.start_request

        expect(statsd_client).to have_received(:gauge).with('cc.requests.outstanding.gauge', 1)
        expect(statsd_client).to have_received(:increment).with('cc.requests.outstanding')
      end
    end

    describe '#complete_request' do
      let(:batch) { double(:batch) }
      let(:status) { 204 }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(statsd_client).to receive(:gauge)
        allow(batch).to receive(:increment)
        allow(batch).to receive(:decrement)
      end

      it 'increments completed, decrements outstanding, increments status for statsd' do
        request_metrics.complete_request(status)

        expect(statsd_client).to have_received(:gauge).with('cc.requests.outstanding.gauge', -1)
        expect(batch).to have_received(:decrement).with('cc.requests.outstanding')
        expect(batch).to have_received(:increment).with('cc.requests.completed')
        expect(batch).to have_received(:increment).with('cc.http_status.2XX')
      end

      it 'normalizes http status codes in statsd' do
        request_metrics.complete_request(200)
        expect(batch).to have_received(:increment).with('cc.http_status.2XX')

        request_metrics.complete_request(300)
        expect(batch).to have_received(:increment).with('cc.http_status.3XX')

        request_metrics.complete_request(400)
        expect(batch).to have_received(:increment).with('cc.http_status.4XX')
      end
    end
  end
end
