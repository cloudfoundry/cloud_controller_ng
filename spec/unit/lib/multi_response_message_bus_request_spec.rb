require 'spec_helper'
require 'cloud_controller/multi_response_message_bus_request'

RSpec.describe MultiResponseMessageBusRequest do
  let(:message_bus) { CfMessageBus::MockMessageBus.new }
  subject(:multi_response_message_bus_request) { described_class.new(message_bus, 'fake nats subject') }

  let!(:timer_stub) { allow(EM).to receive(:add_timer) }

  describe '#request' do
    it 'makes a request' do
      requested_data = nil
      expected_data = { 'request' => 'request-value' }

      message_bus.subscribe('fake nats subject') do |data|
        requested_data = data
      end
      multi_response_message_bus_request.on_response(0) { |*args| }
      multi_response_message_bus_request.request(expected_data)

      expect(requested_data).to eq(expected_data)
    end

    it 'notifies first callback with first response' do
      responses_count = 0
      last_response = nil
      last_error = nil

      multi_response_message_bus_request.on_response(1) do |response, error|
        responses_count += 1
        last_response = response
        last_error = error
      end

      multi_response_message_bus_request.request(request: 'request-value')
      message_bus.respond_to_request('fake nats subject', response: 'response-value')

      expect(responses_count).to eq(1)
      expect(last_error).to be_nil
      expect(last_response).to eq({ 'response' => 'response-value' })
    end

    it 'does not accept responses after the specified timeout and returns an error' do
      responses_count = 0
      last_response = nil
      last_error = nil

      multi_response_message_bus_request.on_response(1) do |response, error|
        responses_count += 1
        last_response = response
        last_error = error
      end

      timer_stub.and_yield
      multi_response_message_bus_request.request(request: 'request-value')

      message_bus.respond_to_request('fake nats subject', response: 'response-value')

      expect(responses_count).to eq(1)
      expect(last_response).to be_nil

      expect(last_error).to be_a(described_class::Error)
      expect(last_error.message).to match /timed out/
    end

    it 'notifies second callback with second response' do
      response1_count = 0
      last1_response = nil
      last1_error = nil

      multi_response_message_bus_request.on_response(0) do |response, error|
        response1_count += 1
        last1_response = response
        last1_error = error
      end

      response2_count = 0
      last2_response = nil
      last2_error = nil

      multi_response_message_bus_request.on_response(0) do |response, error|
        response2_count += 1
        last2_response = response
        last2_error = error
      end

      multi_response_message_bus_request.request(request: 'request-value')
      message_bus.respond_to_request('fake nats subject', 'response1' => 'response-value')
      message_bus.respond_to_request('fake nats subject', 'response2' => 'response-value')

      expect(response1_count).to eq(1)
      expect(last1_response).to eq({ 'response1' => 'response-value' })
      expect(last1_error).to be_nil

      expect(response2_count).to eq(1)
      expect(last2_response).to eq({ 'response2' => 'response-value' })
      expect(last2_error).to be_nil
    end

    it 'does nothing when callbacks were not provided' do
      multi_response_message_bus_request.on_response(0) { |*_| }

      multi_response_message_bus_request.request(request: 'request-value')
      message_bus.respond_to_request('fake nats subject', response: 'response-value')
      message_bus.respond_to_request('fake nats subject', response: 'response-value')
    end

    it 'raises error when no callbacks are specified' do
      expect {
        multi_response_message_bus_request.request(request: 'request-value')
      }.to raise_error(ArgumentError, /at least one callback must be provided/)
    end

    it 'raises error when request is called twice' do
      multi_response_message_bus_request.on_response(0) { |*args| }

      expect {
        multi_response_message_bus_request.request(request: 'request-value')
        multi_response_message_bus_request.request(request: 'request-value')
      }.to raise_error(ArgumentError, /request was already made/)
    end

    it 'does not log to info, to protect sensitive data' do
      logger = double(Steno)
      allow(multi_response_message_bus_request).to receive(:logger).and_return(logger)

      allow(logger).to receive(:debug).with(/sensitive data/)
      expect(logger).not_to receive(:info).with(/sensitive data/)

      multi_response_message_bus_request.on_response(0) { |_| }
      multi_response_message_bus_request.request(request: 'sensitive data')
      message_bus.respond_to_request('fake nats subject', response: 'sensitive data')
    end
  end

  describe '#ignore_subsequent_responses' do
    it 'does not receive subsequent responses' do
      responses_count = 0
      multi_response_message_bus_request.on_response(0) do |data, error|
        responses_count += 1 # Should not get here
      end
      multi_response_message_bus_request.request({})
      multi_response_message_bus_request.ignore_subsequent_responses
      message_bus.respond_to_request('fake nats subject', response: 'response-value')
      expect(responses_count).to eq(0)
    end

    it 'cancels timeout' do
      t = Time.now.utc
      multi_response_message_bus_request.on_response(100) { |*args| raise 'Must never be called' }
      multi_response_message_bus_request.request({})
      multi_response_message_bus_request.ignore_subsequent_responses
      # Since provided timeout was 100 secs
      # if timeout timer does not get cancelled
      # this test will take ~100s instead of less than 100s
      # (Use within 50s instead of 0.1s since system might be busy.)
      expect(Time.now.utc).to be_within(50).of(t)
    end

    it 'raises error when request was not made' do
      expect {
        multi_response_message_bus_request.ignore_subsequent_responses
      }.to raise_error(ArgumentError, /request was not yet made/)
    end

    it 'can ignore subsequent responses from a response callback' do
      responses_count = 0
      multi_response_message_bus_request.on_response(0) do |*args|
        responses_count += 1
        multi_response_message_bus_request.ignore_subsequent_responses
      end
      multi_response_message_bus_request.on_response(0) do |*args|
        responses_count += 1 # Should not get here
      end
      multi_response_message_bus_request.request({})
      message_bus.respond_to_request('fake nats subject', response: 'response-value')
      message_bus.respond_to_request('fake nats subject', response: 'response-value')
      expect(responses_count).to eq(1)
    end
  end
end
