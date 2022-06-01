require 'spec_helper'
require 'cloud_controller/metrics/request_metrics'

module VCAP::CloudController::Metrics
  RSpec.describe RequestMetrics do
    let(:statsd_client) { double(:statsd_client) }
    let(:prometheus_client) { double(:prometheus_client) }
    let!(:request_metrics) { RequestMetrics.new(statsd_client, prometheus_client) } # TODO: probably doesn't need to be a let!, just a let

    before do
      allow(prometheus_client).to receive(:update_gauge_metric)
      allow(prometheus_client).to receive(:decrement_gauge_metric)
      allow(prometheus_client).to receive(:increment_gauge_metric)
    end

    describe '#start_request' do
      before do
        allow(statsd_client).to receive(:increment)
        allow(statsd_client).to receive(:gauge)
      end

      it 'increments outstanding requests for statsd' do
        request_metrics.start_request

        expect(statsd_client).to have_received(:gauge).with('cc.requests.outstanding.gauge', 1)
        expect(statsd_client).to have_received(:increment).with('cc.requests.outstanding')
        expect(prometheus_client).to have_received(:update_gauge_metric).with(:cc_requests_outstanding_gauge, 1, kind_of(String))
        expect(prometheus_client).to have_received(:increment_gauge_metric).with(:cc_requests_outstanding, kind_of(String))
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

        expect(prometheus_client).to have_received(:update_gauge_metric).with(:cc_requests_outstanding_gauge, -1, kind_of(String))
        expect(prometheus_client).to have_received(:decrement_gauge_metric).with(:cc_requests_outstanding, kind_of(String))
        expect(prometheus_client).to have_received(:increment_gauge_metric).with(:cc_requests_completed, kind_of(String))
        expect(prometheus_client).to have_received(:increment_gauge_metric).with(:cc_http_status_2XX, kind_of(String))
      end

      it 'normalizes http status codes in statsd' do
        request_metrics.complete_request(200)
        expect(batch).to have_received(:increment).with('cc.http_status.2XX')
        expect(prometheus_client).to have_received(:increment_gauge_metric).with(:cc_http_status_2XX, kind_of(String))

        request_metrics.complete_request(300)
        expect(batch).to have_received(:increment).with('cc.http_status.3XX')
        expect(prometheus_client).to have_received(:increment_gauge_metric).with(:cc_http_status_3XX, kind_of(String))

        request_metrics.complete_request(400)
        expect(batch).to have_received(:increment).with('cc.http_status.4XX')
        expect(prometheus_client).to have_received(:increment_gauge_metric).with(:cc_http_status_4XX, kind_of(String))
      end
    end
  end
end
