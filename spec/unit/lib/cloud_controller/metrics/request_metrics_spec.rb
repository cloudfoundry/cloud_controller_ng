require 'spec_helper'
require 'cloud_controller/metrics/request_metrics'

module VCAP::CloudController::Metrics
  RSpec.describe RequestMetrics do
    let(:statsd_client) { double(:statsd_client) }
    let!(:request_metrics) { RequestMetrics.new(statsd_client) } # varz is initialized on create so force the new first

    describe 'initializing' do
      it 'inits varz' do
        expected = {
          requests:    { outstanding: 0, completed: 0 },
          http_status: {
            100 => 0, 101 => 0, 200 => 0, 201 => 0, 202 => 0,
            203 => 0, 204 => 0, 205 => 0, 206 => 0, 300 => 0, 301 => 0,
            302 => 0, 303 => 0, 304 => 0, 305 => 0, 306 => 0, 307 => 0,
            400 => 0, 401 => 0, 402 => 0, 403 => 0, 404 => 0, 405 => 0,
            406 => 0, 407 => 0, 408 => 0, 409 => 0, 410 => 0, 411 => 0,
            412 => 0, 413 => 0, 414 => 0, 415 => 0, 416 => 0, 417 => 0,
            418 => 0, 419 => 0, 420 => 0, 421 => 0, 422 => 0,
            500 => 0, 501 => 0, 502 => 0, 503 => 0, 504 => 0, 505 => 0,
          }
        }

        RequestMetrics.new(statsd_client)

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:vcap_sinatra]).to include(expected)
        end
      end
    end

    describe '#start_request' do
      before do
        allow(statsd_client).to receive(:increment)
      end

      it 'increments outstanding requests for varz' do
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:vcap_sinatra][:requests][:outstanding] = 0
        end

        request_metrics.start_request

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:vcap_sinatra][:requests][:outstanding]).to eq(1)
        end
      end

      it 'increments outstanding requests for statsd' do
        request_metrics.start_request

        expect(statsd_client).to have_received(:increment).with('cc.requests.outstanding')
      end
    end

    describe '#complete_request' do
      let(:batch) { double(:batch) }
      let(:status) { 204 }

      before do
        allow(statsd_client).to receive(:batch).and_yield(batch)
        allow(batch).to receive(:increment)
        allow(batch).to receive(:decrement)
      end

      it 'increments completed, decrements outstanding, increments status for varz' do
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:vcap_sinatra][:requests][:outstanding] = 1
          VCAP::Component.varz[:vcap_sinatra][:requests][:completed]   = 0
          VCAP::Component.varz[:vcap_sinatra][:http_status][204]       = 0
        end

        request_metrics.complete_request(status)

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:vcap_sinatra][:requests][:outstanding]).to eq(0)
          expect(VCAP::Component.varz[:vcap_sinatra][:requests][:completed]).to eq(1)
          expect(VCAP::Component.varz[:vcap_sinatra][:http_status][204]).to eq(1)
        end
      end

      it 'increments completed, decrements outstanding, increments status for statsd' do
        request_metrics.complete_request(status)

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
