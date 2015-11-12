require 'spec_helper'
require 'request_logs'

module CloudFoundry
  module Middleware
    describe RequestLogs do
      let(:middleware) { described_class.new(app, logger) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:logger) { double('logger', info: nil) }
      let(:fake_request) { double('request', request_method: 'request_method', ip: 'ip', filtered_path: 'filtered_path') }
      let(:env) { { 'cf.request_id' => 'ID' } }

      describe 'logging' do
        before do
          allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
        end

        it 'returns the app response unaltered' do
          expect(middleware.call(env)).to eq([200, {}, 'a body'])
        end

        it 'logs before calling the app' do
          middleware.call(env)
          expect(logger).to have_received(:info).with(/Started.+vcap-request-id: ID/)
        end

        it 'logs after calling the app' do
          middleware.call(env)
          expect(logger).to have_received(:info).with(/Completed.+vcap-request-id: ID/)
        end
      end
    end
  end
end
