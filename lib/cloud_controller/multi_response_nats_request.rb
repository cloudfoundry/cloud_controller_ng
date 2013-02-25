# Can be used to run custom callback for each NATS response
class MultiResponseNatsRequest
  class Error < StandardError; end

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

    @sid = @nats.request(@subject, Yajl.dump(data)) do |response|
      handle_received_response(response)
    end

    logger.info "request: sid=#{@sid} response='#{data}'"
    timeout_request
  end

  def ignore_subsequent_responses
    raise ArgumentError, "request was not yet made" unless @sid

    EM.cancel_timer(@timeout) if @timeout
    unsubscribe
  end

  private

  def handle_received_response(response)
    logger.info "handle_received_response: sid=#{@sid} response='#{response}'"

    begin
      parsed_response = Yajl.load(response)
    rescue Yajl::ParseError => e
      logger.info("Failed decoding response: #{e}\n#{e.backtrace}")
      error = Error.new("Internal error: failed to decode response")
    end

    timeout_request
    trigger_on_response(parsed_response, error)
  end

  def trigger_on_response(response, error)
    if response_callback = @responses.pop
      response_callback.call(response, error)
    end
  end

  def timeout_request
    EM.cancel_timer(@timeout) if @timeout

    if secs = @response_timeouts.pop
      logger.info "timeout_request: sid=#{@sid} timeout=#{secs}"

      @timeout = EM.add_timer(secs) do
        unsubscribe
        trigger_on_response(nil, Error.new("Operation timed out"))
      end
    end
  end

  def unsubscribe
    logger.info "unsubscribe: sid=#{@sid}"
    @nats.unsubscribe(@sid)
  end

  def logger
    @logger ||= Steno.logger(self.class.name)
  end
end
