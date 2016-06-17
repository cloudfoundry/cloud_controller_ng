require 'spec_helper'
require 'request_metrics'

module CloudFoundry
  module Middleware
    RSpec.describe RequestMetrics do
      let(:middleware) { described_class.new(app, request_metrics) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:request_metrics) { instance_double(VCAP::CloudController::Metrics::RequestMetrics, start_request: nil, complete_request: nil) }

      describe 'handling the request' do
        it 'calls start request on request metrics before the request' do
          middleware.call({})
          expect(request_metrics).to have_received(:start_request)
        end

        it 'calls complete request on request metrics after the request' do
          middleware.call({})
          expect(request_metrics).to have_received(:complete_request).with(200)
        end
      end
    end
  end
end
