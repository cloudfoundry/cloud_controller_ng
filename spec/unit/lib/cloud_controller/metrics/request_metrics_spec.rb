require 'spec_helper'
require 'cloud_controller/metrics/request_metrics'

module VCAP::CloudController::Metrics
  RSpec.describe RequestMetrics do
    let(:statsd_client) { double(:statsd_client) }
    let!(:request_metrics) { RequestMetrics.new(statsd_client) } # TODO: probably doesn't need to be a let!, just a let

    describe '#start_request' do
      before do
        allow(statsd_client).to receive(:increment)
      end

      it 'increments outstanding requests for statsd' do
        request_metrics.start_request

        expect(statsd_client).to have_received(:increment).with('cc.requests.outstanding')
      end
    end

    describe '#complete_request' do
      let(:batch) { double(:batch) }
      let(:path) { '/v2/some-path' }
      let(:method) { 'GET' }
      let(:status) { 204 }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:increment)
        allow(batch).to receive(:decrement)
      end

      it 'increments completed, decrements outstanding, increments status for statsd' do
        request_metrics.complete_request(path, method, status)

        expect(batch).to have_received(:decrement).with('cc.requests.outstanding')
        expect(batch).to have_received(:increment).with('cc.requests.completed')
        expect(batch).to have_received(:increment).with('cc.http_status.2XX')
      end

      it 'normalizes http status codes in statsd' do
        request_metrics.complete_request(path, method, 200)
        expect(batch).to have_received(:increment).with('cc.http_status.2XX')

        request_metrics.complete_request(path, method, 300)
        expect(batch).to have_received(:increment).with('cc.http_status.3XX')

        request_metrics.complete_request(path, method, 400)
        expect(batch).to have_received(:increment).with('cc.http_status.4XX')
      end

      it 'sends extra metrics for /service_instances calls' do
        request_metrics.complete_request('/v2/service_instances', 'GET', 200)
        expect(batch).to have_received(:increment).with('cc.requests.service_instances.get.http_status.2XX')
      end

      it 'sends extra metrics for /service_bindings calls' do
        request_metrics.complete_request('/v2/service_bindings', 'GET', 200)
        expect(batch).to have_received(:increment).with('cc.requests.service_bindings.get.http_status.2XX')
      end

      it 'sends extra metrics for /service_keys calls' do
        request_metrics.complete_request('/v2/service_keys', 'GET', 200)
        expect(batch).to have_received(:increment).with('cc.requests.service_keys.get.http_status.2XX')
      end
    end
  end
end
