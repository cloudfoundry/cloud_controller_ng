module VCAP::CloudController
  module SidecarMixin
    def process_types
      sidecar_process_types.map(&:type).sort
    end

    def to_hash
      {
        name: name,
        command: command,
        types: process_types
      }
    end
  end
end
