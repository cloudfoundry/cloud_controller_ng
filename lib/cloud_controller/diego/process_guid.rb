module VCAP::CloudController
  module Diego
    class ProcessGuid
      def self.from(process_guid, process_version)
        "#{process_guid}-#{process_version}"
      end

      def self.from_process(process)
        from(process.guid, process.version)
      end

      def self.app_guid(versioned_guid)
        versioned_guid[0..35]
      end

      def self.app_version(versioned_guid)
        versioned_guid[37..-1]
      end
    end
  end
end
