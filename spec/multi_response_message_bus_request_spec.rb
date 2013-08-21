require "spec_helper"
require "cloud_controller/multi_response_message_bus_request"

describe MultiResponseMessageBusRequest do
  let(:message_bus) { CfMessageBus::MockMessageBus.new }
  subject { described_class.new(message_bus, "subject") }

  let!(:timer_stub) { EM.stub(:add_timer) }

  describe "#request" do
    it "makes a request" do
      requested_data = nil
      expected_data = { :request => "request-value" }

      message_bus.subscribe("subject") do |data|
        requested_data = data
      end
      subject.on_response(0) { |*args| }
      subject.request(expected_data)

      requested_data.should == expected_data
    end

    it "notifies first callback with first response" do
      responses_count = 0
      last_response = nil
      last_error = nil

      subject.on_response(1) do |response, error|
        responses_count += 1
        last_response = response
        last_error = error
      end

      subject.request(:request => "request-value")
      message_bus.respond_to_request("subject", :response => "response-value")

      responses_count.should == 1
      last_error.should be_nil
      last_response.should == { :response => "response-value" }
    end

    it "does not accept responses after the specified timeout and returns an error" do
      responses_count = 0
      last_response = nil
      last_error = nil

      subject.on_response(1) do |response, error|
        responses_count += 1
        last_response = response
        last_error = error
      end

      timer_stub.and_yield
      subject.request(:request => "request-value")

      message_bus.respond_to_request("subject", :response => "response-value")

      responses_count.should == 1
      last_response.should be_nil

      last_error.should be_a(described_class::Error)
      last_error.message.should match /timed out/
    end

    it "does not accept responses after the specified timeout for subsequent requests" do
      response1_count = 0
      subject.on_response(2) do |response, error|
        response1_count += 1
      end

      response2_count = 0
      subject.on_response(4) do |response, error|
        response2_count += 1
      end

      subject.request(:request => "request-value")

      # send response within first response timeout
      message_bus.respond_to_request("subject", "response1" => "response-value")

      timer_stub.and_yield

      # send response within second response timeout
      # but after first response timeout expires
      message_bus.respond_to_request("subject", "response2" => "response-value")

      response1_count.should == 1
      response2_count.should == 1
    end

    it "notifies second callback with second response" do
      response1_count = 0
      last1_response = nil
      last1_error = nil

      subject.on_response(0) do |response, error|
        response1_count += 1
        last1_response = response
        last1_error = error
      end

      response2_count = 0
      last2_response = nil
      last2_error = nil

      subject.on_response(0) do |response, error|
        response2_count += 1
        last2_response = response
        last2_error = error
      end

      subject.request(:request => "request-value")
      message_bus.respond_to_request("subject", "response1" => "response-value")
      message_bus.respond_to_request("subject", "response2" => "response-value")

      response1_count.should == 1
      last1_response.should == { :response1 => "response-value" }
      last1_error.should be_nil

      response2_count.should == 1
      last2_response.should == { :response2 => "response-value" }
      last2_error.should be_nil
    end

    it "does nothing when callbacks were not provided" do
      subject.on_response(0) { |*args| }

      subject.request(:request => "request-value")
      message_bus.respond_to_request("subject", :response => "response-value")
      message_bus.respond_to_request("subject", :response => "response-value")
    end

    it "raises error when no callbacks are specified" do
      expect {
        subject.request(:request => "request-value")
      }.to raise_error(ArgumentError, /at least one callback must be provided/)
    end

    it "raises error when request is called twice" do
      subject.on_response(0) { |*args| }

      expect {
        subject.request(:request => "request-value")
        subject.request(:request => "request-value")
      }.to raise_error(ArgumentError, /request was already made/)
    end
  end

  describe "#ignore_subsequent_responses" do
    it "does not receive subsequent responses" do
      responses_count = 0
      subject.on_response(0) do |data, error|
        responses_count += 1 # Should not get here
      end
      subject.request({})
      subject.ignore_subsequent_responses
      message_bus.respond_to_request("subject", :response => "response-value")
      responses_count.should == 0
    end

    it "cancels timeout" do
      t = Time.now
      subject.on_response(100) { |*args| raise "Must never be called" }
      subject.request({})
      subject.ignore_subsequent_responses
      # Since provided timeout was 100 secs
      # if timeout timer does not get cancelled
      # this test will take ~100s instead of less than 100s
      # (Use within 50s instead of 0.1s since system might be busy.)
      Time.now.should be_within(50).of(t)
    end

    it "raises error when request was not made" do
      expect {
        subject.ignore_subsequent_responses
      }.to raise_error(ArgumentError, /request was not yet made/)
    end

    it "can ignore subsequent responses from a response callback" do
      responses_count = 0
      subject.on_response(0) do |*args|
        responses_count += 1
        subject.ignore_subsequent_responses
      end
      subject.on_response(0) do |*args|
        responses_count += 1 # Should not get here
      end
      subject.request({})
      message_bus.respond_to_request("subject", :response => "response-value")
      message_bus.respond_to_request("subject", :response => "response-value")
      responses_count.should == 1
    end
  end
end
