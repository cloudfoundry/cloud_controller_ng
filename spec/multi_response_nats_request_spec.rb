require "spec_helper"
require "cloud_controller/multi_response_nats_request"

describe MultiResponseNatsRequest do
  let(:mock_nats) { NatsClientMock.new({}) }
  subject { described_class.new(mock_nats, "subject") }

  def run_em(options={}, &blk)
    EM.run do
      blk.call
      EM.next_tick { EM.stop } unless options[:manual_stop]
    end
  end

  describe "#request" do
    it "makes a request" do
      requested_data = nil
      expected_data = {"request" => "request-value"}

      run_em do
        mock_nats.subscribe("subject") do |data|
          requested_data = data
        end
        subject.on_response(0) { |*args| }
        subject.request(expected_data)
      end

      requested_data.should == JSON.dump(expected_data)
    end

    it "notifies first callback with first response" do
      responses_count = 0
      last_response = nil
      last_error = nil

      subject.on_response(1) do |response, error|
        responses_count = 1
        last_response = response
        last_error = error
      end

      run_em do
        subject.request("request" => "request-value")
        mock_nats.reply_to_last_request("subject", "response" => "response-value")
      end

      responses_count.should == 1
      last_response.should == {"response" => "response-value"}
      last_error.should be_nil
    end

    it "does not accept responses after the specified timeout" do
      responses_count = 0
      subject.on_response(1) do |response, error|
        responses_count = 1
      end

      run_em do
        subject.request("request" => "request-value")

        EM.add_timer(2) do
          mock_nats.reply_to_last_request("subject", "response" => "response-value")
          EM.next_tick { EM.stop }
        end
      end

      responses_count.should == 0
    end

    it "does not accept responses after the specified timeout for subsequent requests" do
      response1_count = 0
      subject.on_response(2) do |response, error|
        response1_count = 1
      end

      response2_count = 0
      subject.on_response(4) do |response, error|
        response2_count = 1
      end

      run_em(:manual_stop => true) do
        subject.request("request" => "request-value")

        # send response within first response timeout
        EM.add_timer(1) do
          mock_nats.reply_to_last_request("subject", "response" => "response-value")

          # send response within second response timeout
          # but after first response timeout expires
          EM.add_timer(2) do
            mock_nats.reply_to_last_request("subject", "response" => "response-value")
            EM.next_tick { EM.stop }
          end
        end
      end

      response1_count.should == 1
      response2_count.should == 1
    end

    it "notifies callback with an error" do
      responses_count = 0
      last_response = nil
      last_error = nil

      subject.on_response(0) do |response, error|
        responses_count = 1
        last_response = response
        last_error = error
      end

      run_em do
        subject.request("request" => "request-value")
        mock_nats.reply_to_last_request("subject", nil, :invalid_json => true)
      end

      responses_count.should == 1
      last_response.should be_nil
      last_error.should be_a(VCAP::Stager::Client::Error)
    end

    it "notifies second callback with second response" do
      response1_count = 0
      last1_response = nil
      last1_error = nil

      subject.on_response(0) do |response, error|
        response1_count = 1
        last1_response = response
        last1_error = error
      end

      response2_count = 0
      last2_response = nil
      last2_error = nil

      subject.on_response(0) do |response, error|
        response2_count = 1
        last2_response = response
        last2_error = error
      end

      run_em do
        subject.request("request" => "request-value")
        mock_nats.reply_to_last_request("subject", "response1" => "response-value")

        response1_count.should == 1
        last1_response.should == {"response1" => "response-value"}
        last1_error.should be_nil

        response2_count.should == 0
        last2_response.should be_nil
        last2_error.should be_nil

        mock_nats.reply_to_last_request("subject", "response2" => "response-value")

        response2_count.should == 1
        last2_response.should == {"response2" => "response-value"}
        last2_error.should be_nil
      end
    end

    it "does nothing when callbacks were not provided" do
      subject.on_response(0) { |*args| }

      run_em do
        subject.request("request" => "request-value")
        mock_nats.reply_to_last_request("subject", "response" => "response-value")
        mock_nats.reply_to_last_request("subject", "response" => "response-value")
      end
    end

    it "raises error when no callbacks are specified" do
      expect {
        run_em { subject.request("request" => "request-value") }
      }.to raise_error(ArgumentError, /at least one callback must be provided/)
    end

    it "raises error when request is called twice" do
      subject.on_response(0) { |*args| }

      expect {
        run_em do
          subject.request("request" => "request-value")
          subject.request("request" => "request-value")
        end
      }.to raise_error(ArgumentError, /request was already made/)
    end
  end
end
