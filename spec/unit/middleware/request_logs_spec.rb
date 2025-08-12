require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    RSpec.describe RequestLogs do
      let(:middleware) { RequestLogs.new(app, request_logs) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:request_logs) { instance_double(VCAP::CloudController::Logs::RequestLogs, start_request: nil, complete_request: nil) }
      let(:env) { { 'cf.request_id' => 'ID' } }

      describe 'handling the request' do
        before do
          VCAP::CloudController::Config.config.get(:db)[:log_db_queries] = true
        end

        it 'calls start request on request logs before the request' do
          middleware.call(env)
          expect(request_logs).to have_received(:start_request).with('ID', env)
        end

        it 'returns the app response unaltered' do
          expect(middleware.call(env)).to eq([200, {}, 'a body'])
        end

        it 'calls complete request on request logs after the request' do
          middleware.call(env)
          expect(request_logs).to have_received(:complete_request).with('ID', 200, { 'cf.request_id' => 'ID' }, be_a(Numeric), be_a(Numeric), be_a(Numeric))
        end
      end

      describe 'when db query logging is disabled' do
        before do
          VCAP::CloudController::Config.config.get(:db)[:log_db_queries] = false
        end

        it 'calls complete request on request logs without db query metrics' do
          middleware.call(env)
          expect(request_logs).to have_received(:complete_request).with('ID', 200, { 'cf.request_id' => 'ID' }, be_a(Numeric))
        end
      end
    end
  end
end
