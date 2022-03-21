require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Metrics' do
  let(:threadqueue) { double(EventMachine::Queue, size: 20, num_waiting: 0) }
  let(:resultqueue) { double(EventMachine::Queue, size: 0, num_waiting: 1) }

  let(:user) { VCAP::CloudController::User.make }
  let(:admin_header) { admin_headers_for(user) }

  before do
    allow(EventMachine).to receive(:connection_count).and_return(123)

    allow(EventMachine).to receive(:instance_variable_get) do |instance_var|
      case instance_var
      when :@threadqueue
        threadqueue
      when :@resultqueue
        resultqueue
      else
        raise "Unexpected call: #{instance_var}"
      end
    end
  end

  describe 'GET /v3/metrics' do
    it 'succeeds' do
      get 'v3/metrics', nil, admin_header
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq '
     some stuff
      '
    end
  end
end
