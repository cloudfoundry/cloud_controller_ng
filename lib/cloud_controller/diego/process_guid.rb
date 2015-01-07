module VCAP::CloudController
  module Diego
    class ProcessGuid
      def self.from(app_guid, app_version)
        "#{app_guid}-#{app_version}"
      end

      def self.from_app(app)
        from(app.guid, app.version)
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
