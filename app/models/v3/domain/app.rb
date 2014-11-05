module VCAP::CloudController
  class AppV3
    attr_reader :guid, :processes, :space_guid
    attr_reader :changes

    def initialize(opts, changes={})
      @guid = opts[:guid]
      @processes = opts[:processes]
      @space_guid = opts[:space_guid]

      @changes = changes
    end
  end
end
