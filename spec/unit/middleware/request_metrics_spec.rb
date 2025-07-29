require 'spec_helper'
require 'request_metrics'

module CloudFoundry
  module Middleware
    RSpec.describe RequestMetrics do
      let(:middleware) { RequestMetrics.new(app, request_metrics) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:request_metrics) { instance_double(VCAP::CloudController::Metrics::RequestMetrics, start_request: nil, complete_request: nil) }

      describe 'handling the request' do
        it 'resets the db query count and calls start request on request metrics before the request' do
          expect(VCAP::Request).to receive(:reset_db_query_metrics)
          middleware.call({})
          expect(request_metrics).to have_received(:start_request)
        end

        it 'returns the app response unaltered' do
          expect(middleware.call({})).to eq([200, {}, 'a body'])
        end

        it 'calls complete request on request metrics after the request' do
          middleware.call({})
          expect(request_metrics).to have_received(:complete_request).with(200)
        end

        context 'when an unexpected error occurs' do
          let(:middleware) { RequestMetrics.new(app, request_metrics) }
          let(:app) { double(:app) }

          before do
            allow(app).to receive(:call).and_raise('Unexpected')
          end

          it 'catches the exception and calls complete request on request metrics' do
            expect { middleware.call({}) }.to raise_error('Unexpected') do
              expect(request_metrics).to have_received(:complete_request).with(500)
            end
          end
        end
      end
    end
  end
end
