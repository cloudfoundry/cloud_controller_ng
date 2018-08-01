require 'spec_helper'
require 'newrelic_rpm'

module CloudFoundry
  module Middleware
    RSpec.describe NewRelicCustomAttributes do
      let(:app) { double(:app, call: [200, { some: 'header' }, 'a body']) }
      let(:middleware) { NewRelicCustomAttributes.new(app) }
      let(:request_id) { 'abc123' }

      before do
        allow(NewRelic::Agent).to receive(:add_custom_attributes)
      end

      it 'adds the vcap-request-id to all New Relic events' do
        middleware.call({ 'cf.request_id' => request_id })
        expect(NewRelic::Agent).to have_received(:add_custom_attributes).with({ vcap_request_id: request_id })
      end

      it 'passes the response information along without touching it' do
        response = middleware.call({ 'cf.request_id' => request_id })
        expect(response).to eq([200, { some: 'header' }, 'a body'])
      end
    end
  end
end
