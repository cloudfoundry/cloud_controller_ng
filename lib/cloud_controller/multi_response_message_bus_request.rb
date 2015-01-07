# Can be used to run different callbacks for each message bus response
class MultiResponseMessageBusRequest
  class Error < StandardError; end

  def initialize(message_bus, subject)
    @message_bus = message_bus
    @subject = subject
    @responses = []
    @response_timeouts = []
  end

  def on_response(timeout, &response_callback)
    @responses.insert(0, response_callback)
    @response_timeouts.insert(0, timeout)
  end

  def request(data)
    raise ArgumentError.new('at least one callback must be provided') if @responses.empty?
    raise ArgumentError.new('request was already made') if @sid

    @sid = @message_bus.request(@subject, data) do |response, error|
      handle_received_response(response, error)
    end

    logger.debug "request: sid=#{@sid} response='#{data}'"
    timeout_request
  end

  def ignore_subsequent_responses
    raise ArgumentError.new('request was not yet made') unless @sid

    EM.cancel_timer(@timeout) if @timeout
    unsubscribe
  end

  private

  def handle_received_response(response, response_error=nil)
    logger.debug "handle_received_response: sid=#{@sid} response='#{response}'"

    error = Error.new('Internal error: failed to decode response') if response_error
    timeout_request
    trigger_on_response(response, error)
  end

  def trigger_on_response(response, error)
    return unless (response_callback = @responses.pop)
    response_callback.call(response, error)
  end

  def timeout_request
    EM.cancel_timer(@timeout) if @timeout

    if (secs = @response_timeouts.pop)
      logger.info "timeout_request: sid=#{@sid} timeout=#{secs}"

      @timeout = EM.add_timer(secs) do
        unsubscribe
        trigger_on_response(nil, Error.new('Operation timed out'))
      end
    end
  end

  def unsubscribe
    logger.info "unsubscribe: sid=#{@sid}"
    @message_bus.unsubscribe(@sid)
  end

  def logger
    @logger ||= Steno.logger(self.class.name)
  end
end
