require 'spec_helper'

module VCAP::CloudController
  module Internal
    RSpec.describe MetricsController do
      let(:threadqueue) { double(EventMachine::Queue, size: 20, num_waiting: 0) }
      let(:resultqueue) { double(EventMachine::Queue, size: 0, num_waiting: 1) }

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

      describe '#index' do
        it 'returns a 200' do
          get '/internal/v4/metrics'

          expect(last_response.status).to eq 200
          expect(last_response.body).to match(/cc_vitals_num_cores [1-9][0-9]*.\d+/)
        end
      end
    end
  end
end
