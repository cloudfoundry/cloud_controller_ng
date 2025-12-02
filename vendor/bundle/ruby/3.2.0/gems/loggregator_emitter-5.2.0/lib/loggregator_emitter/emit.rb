require 'socket'
require 'resolv'
require 'sonde'

module LoggregatorEmitter
  class Emitter

    UDP_SEND_ERROR = StandardError.new("Error sending message via UDP")

    attr_reader :host

    MAX_MESSAGE_BYTE_SIZE = (9 * 1024) - 512
    TRUNCATED_STRING = "TRUNCATED"
    MAX_TAG_LENGTH = 256
    MAX_TAGS = 10

    def initialize(loggregator_server, origin, source_type, source_instance = nil)
      @host, @port = loggregator_server.split(/:([^:]*$)/)

      raise ArgumentError, "Must provide valid loggregator server: #{loggregator_server}" if !valid_hostname || !valid_port
      @host = ::Resolv.getaddresses(@host).first
      raise ArgumentError, "Must provide valid loggregator server: #{loggregator_server}" unless @host

      raise ArgumentError, "Must provide a valid origin" unless origin
      raise ArgumentError, "Must provide valid source_type: #{source_type}" unless source_type

      raise ArgumentError, "source_type must be a 3-character string" unless source_type.is_a? String
      raise ArgumentError, "Custom Source String must be 3 characters" unless source_type.size == 3
      @origin = origin
      @source_type = source_type

      @source_instance = source_instance && source_instance.to_s
    end

    def emit(app_id, message, tags = nil)
      emit_message(app_id, message, LogMessage::MessageType::OUT, tags)
    end

    def emit_error(app_id, message, tags = nil)
      emit_message(app_id, message, LogMessage::MessageType::ERR, tags)
    end

    def emit_value_metric(name, value, unit, tags = nil)
      return unless name && value && unit

      send_protobuffer(create_value_metric_envelope(name, value, unit, tags))
    end

    def emit_counter(name, delta, tags = nil)
      return unless name && delta

      send_protobuffer(create_counter_envelope(name, delta, tags))
    end

    def emit_container_metric(app_id, instanceIndex, cpu, memory, disk, tags = nil)
      return unless app_id && instanceIndex && cpu && memory && disk

      send_protobuffer(create_container_metric_envelope(app_id, instanceIndex, cpu, memory, disk, tags))
    end

    private

    def valid_port
      @port && @port.match(/^\d+$/)
    end

    def valid_hostname
      @host && !@host.empty? && !@host.match(/:\/\//)
    end

    def split_message(message)
      message.split(/\n|\r/).reject { |a| a.empty? }
    end

    def set_tags(tags)
      if tags.length > MAX_TAGS
        raise ArgumentError, "Too many tags. Max is #{MAX_TAGS}"
      end
      envelope_tags = []
      tags.each do |k, v|
        raise ArgumentError, "Tag key is too long: #{k.length} (max #{MAX_TAG_LENGTH} characters)" unless k.length <= MAX_TAG_LENGTH
        raise ArgumentError, "Tag value is too long #{v.length} (max #{MAX_TAG_LENGTH} characters)" unless v.length <= MAX_TAG_LENGTH
        envelope_tags << ::Sonde::Envelope::TagsEntry.new(:key => k, :value => v)
      end
      envelope_tags
    end

    def emit_message(app_id, message, type, tags = nil)
      return unless app_id && message && message.strip.length > 0

      split_message(message).each do |m|
        if m.bytesize > MAX_MESSAGE_BYTE_SIZE
          m = m.byteslice(0, MAX_MESSAGE_BYTE_SIZE-TRUNCATED_STRING.bytesize) + TRUNCATED_STRING
        end

        send_protobuffer(create_log_envelope(app_id, m, type, tags))
      end
    end

    def create_log_message(app_id, message, type, time)
      lm = ::Sonde::LogMessage.new()
      lm.time = time
      lm.message = message
      lm.app_id = app_id
      lm.source_instance = @source_instance
      lm.source_type = @source_type
      lm.message_type = type
      lm
    end

    def create_log_envelope(app_id, message, type, tags = nil)
      le = ::Sonde::Envelope.new()
      le.origin = @origin
      le.time = Time.now
      le.eventType = ::Sonde::Envelope::EventType::LogMessage
      le.logMessage = create_log_message(app_id, message, type, le.time)
      if tags != nil
        le.tags = set_tags(tags)
      end
      le
    end

    def create_value_metric(name, value, unit)
      metric = ::Sonde::ValueMetric.new()
      metric.name = name
      metric.value = value
      metric.unit = unit
      metric
    end

    def create_value_metric_envelope(name, value, unit, tags = nil)
      envelope = ::Sonde::Envelope.new()
      envelope.time = Time.now
      envelope.origin = @origin
      envelope.eventType = ::Sonde::Envelope::EventType::ValueMetric
      envelope.valueMetric = create_value_metric(name, value, unit)
      if tags != nil
        envelope.tags = set_tags(tags)
      end
      envelope
    end

    def create_counter_event(name, delta)
      counter = ::Sonde::CounterEvent.new()
      counter.name = name
      counter.delta = delta
      counter
    end

    def create_counter_envelope(name, delta, tags = nil)
      envelope = ::Sonde::Envelope.new()
      envelope.time = Time.now
      envelope.origin = @origin
      envelope.eventType = ::Sonde::Envelope::EventType::CounterEvent
      envelope.counterEvent = create_counter_event(name, delta)
      if tags != nil
        envelope.tags = set_tags(tags)
      end
      envelope
    end

    def create_container_metric(app_id, instanceIndex, cpu, memory, disk)
      metric = ::Sonde::ContainerMetric.new()
      metric.applicationId = app_id
      metric.instanceIndex = instanceIndex
      metric.cpuPercentage = cpu
      metric.memoryBytes = memory
      metric.diskBytes = disk
      metric
    end

    def create_container_metric_envelope(app_id, instanceIndex, cpu, memory, disk, tags = nil)
      envelope = ::Sonde::Envelope.new()
      envelope.time = Time.now
      envelope.origin = @origin
      envelope.eventType = ::Sonde::Envelope::EventType::ContainerMetric
      envelope.containerMetric = create_container_metric(app_id, instanceIndex, cpu, memory, disk)
      if tags != nil
        envelope.tags = set_tags(tags)
      end
      envelope
    end

    def send_protobuffer(lm)
      result = lm.encode.buf
      result.unpack("C*")

      addrinfo_udp = Addrinfo.udp(@host, @port)
      s = addrinfo_udp.ipv4?() ? UDPSocket.new : UDPSocket.new(Socket::AF_INET6)
      s.do_not_reverse_lookup = true

      begin
        s.sendmsg_nonblock(result, 0, addrinfo_udp)
      rescue
        raise UDP_SEND_ERROR
      end
    end
  end
end
