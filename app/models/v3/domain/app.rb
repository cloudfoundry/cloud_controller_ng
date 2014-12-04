module VCAP::CloudController
  class AppV3
    attr_reader :guid, :processes, :space_guid, :name

    def initialize(opts)
      @guid = opts[:guid]
      @name = opts[:name]
      @processes = opts[:processes]
      @space_guid = opts[:space_guid]
    end
  end
end
