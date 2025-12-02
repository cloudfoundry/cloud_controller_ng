module Fog
  module Google
    class Storage < Fog::Service
      def self.new(options = {})
        begin
          fog_creds = Fog.credentials
        rescue StandardError
          fog_creds = nil
        end

        if options.keys.include?(:google_storage_access_key_id) ||
           (!fog_creds.nil? && fog_creds.keys.include?(:google_storage_access_key_id))
          Fog::Google::StorageXML.new(options)
        else
          Fog::Google::StorageJSON.new(options)
        end
      end
    end
  end
end
