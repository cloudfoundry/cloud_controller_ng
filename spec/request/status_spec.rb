require 'spec_helper'

module VCAP::CloudController
  RSpec.describe 'Status Endpoint' do
    include Rack::Test::Methods

    let(:metrics_webserver) { ApiMetricsWebserver.new }

    delegate :app, to: :metrics_webserver

    describe 'GET /internal/v4/status' do
      context 'when all workers are busy and unhealthy' do
        before do
          allow(Puma).to receive(:stats_hash).and_return(
            worker_status: [
              { last_status: { busy_threads: 2, running: 2, requests_count: 5 } },
              { last_status: { busy_threads: 1, running: 1, requests_count: 3 } }
            ]
          )
          allow(metrics_webserver).to receive(:determine_unhealthy_state).and_return(true)
        end

        it 'returns 503 UNHEALTHY' do
          get '/internal/v4/status'

          expect(last_response.status).to eq(503)
          expect(last_response.body).to eq('UNHEALTHY')
        end
      end

      context 'when all workers are busy but not unhealthy' do
        before do
          allow(Puma).to receive(:stats_hash).and_return(
            worker_status: [
              { last_status: { busy_threads: 2, running: 2, requests_count: 5 } },
              { last_status: { busy_threads: 1, running: 1, requests_count: 3 } }
            ]
          )
          allow(metrics_webserver).to receive(:determine_unhealthy_state).and_return(false)
        end

        it 'returns 429 BUSY' do
          get '/internal/v4/status'

          expect(last_response.status).to eq(429)
          expect(last_response.body).to eq('BUSY')
        end
      end

      context 'when not all workers are busy' do
        before do
          allow(Puma).to receive(:stats_hash).and_return(
            worker_status: [
              { last_status: { busy_threads: 1, running: 2, requests_count: 5 } },
              { last_status: { busy_threads: 0, running: 1, requests_count: 3 } }
            ]
          )
        end

        it 'returns 200 OK' do
          get '/internal/v4/status'

          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq('OK')
        end
      end
    end
  end
end
