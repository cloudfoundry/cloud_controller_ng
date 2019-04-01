module VCAP::CloudController
  class NonManifestStrategy
    def initialize(message, process)
      @process = process
      @message = message
    end

    def updated_command
      @message.command
    end
  end
end
