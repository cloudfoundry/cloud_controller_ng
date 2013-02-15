# Can be used to run custom callback for each NATS response
class MultiResponseNatsRequest
  def initialize(nats, subject)
    @nats = nats
    @subject = subject
    @responses = []
    @response_timeouts = []
  end

  def on_response(timeout, &response_callback)
    @responses.insert(0, response_callback)
    @response_timeouts.insert(0, timeout)
  end

  def request(data)
    raise ArgumentError, "at least one callback must be provided" if @responses.empty?
    raise ArgumentError, "request was already made" if @sid

    @sid = @nats.request(@subject, data) do |response|
      next unless response_callback = @responses.pop
      timeout_request

      begin
        parsed_response = Yajl.load(response)
      rescue Yajl::ParseError => e
        error_msg = "Failed decoding response: #{e}\n#{e.backtrace}"
        error = VCAP::Stager::Client::Error.new(error_msg)
      end

      response_callback.call(parsed_response, error)
    end

    timeout_request
  end

  def ignore_subsequent_responses
    raise ArgumentError, "request was not yet made" unless @sid
    EM.cancel_timer(@timeout) if @timeout
    unsubscribe
  end

  private

  def timeout_request
    EM.cancel_timer(@timeout) if @timeout
    @timeout = EM.add_timer(@response_timeouts.pop) do
      unsubscribe
    end
  end

  def unsubscribe
    @nats.unsubscribe(@sid)
  end
end
