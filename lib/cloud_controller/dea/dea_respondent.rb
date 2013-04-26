module VCAP::CloudController
  class << self
    attr_accessor :dea_respondent
  end

  class DeaRespondent
    attr_reader :logger, :config
    attr_reader :message_bus

    def initialize(config, message_bus)
      @logger = config.fetch(:logger, Steno.logger("cc.dea_respondent"))
      @message_bus = message_bus
      @config = config

      subject = "droplet.exited"
      message_bus.subscribe(subject) do |decoded_msg|
        process_droplet_exited_message(decoded_msg)
      end
    end

    def crashed_app?(decoded_message)
      decoded_message[:reason] && decoded_message[:reason].downcase == "crashed"
    end

    def process_droplet_exited_message(decoded_message)
      app_guid = decoded_message[:droplet]
      app = Models::App[:guid => app_guid]
      if app && crashed_app?(decoded_message)
        crash_event = Models::CrashEvent.create(
          :app_id => app.id,
          :instance_guid => decoded_message[:instance],
          :instance_index => decoded_message[:index],
          :exit_status => decoded_message[:exit_status],
          :exit_description => decoded_message[:exit_description]
        )
      end
    end
  end
end