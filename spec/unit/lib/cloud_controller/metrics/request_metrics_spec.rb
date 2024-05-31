require 'spec_helper'
require 'cloud_controller/metrics/request_metrics'

module VCAP::CloudController::Metrics
  RSpec.describe RequestMetrics do
    let(:statsd_updater) { double(:statsd_updater) }
    let(:prometheus_client) { double(:prometheus_client) }
    let(:request_metrics) { RequestMetrics.new(statsd_updater, prometheus_client) }

    before do
      allow(prometheus_client).to receive(:update_gauge_metric)
      allow(prometheus_client).to receive(:decrement_gauge_metric)
      allow(prometheus_client).to receive(:increment_gauge_metric)
      allow(prometheus_client).to receive(:increment_counter_metric)
      allow(statsd_updater).to receive(:start_request)
      allow(statsd_updater).to receive(:complete_request)
    end

    describe '#start_request' do
      it 'increments outstanding requests for statsd' do
        request_metrics.start_request
        expect(statsd_updater).to have_received(:start_request)
      end

      it 'increments outstanding requests for prometheus' do
        request_metrics.start_request
        expect(prometheus_client).to have_received(:increment_gauge_metric).with(:cc_requests_outstanding_total)
      end
    end

    describe '#complete_request' do
      let(:status) { 204 }

      it 'increments completed, decrements outstanding, increments status for statsd' do
        request_metrics.complete_request(status)
        expect(statsd_updater).to have_received(:complete_request).with(status)
      end

      it 'increments completed and decrements outstanding for prometheus' do
        request_metrics.complete_request(status)

        expect(prometheus_client).to have_received(:decrement_gauge_metric).with(:cc_requests_outstanding_total)
        expect(prometheus_client).to have_received(:increment_counter_metric).with(:cc_requests_completed_total)
      end
    end
  end
end
