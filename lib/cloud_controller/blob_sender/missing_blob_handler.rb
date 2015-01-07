module CloudController
  module BlobSender
    class MissingBlobHandler
      def handle_missing_blob!(app_guid, name)
        Loggregator.emit_error(app_guid, "Did not find #{name} for app with guid: #{app_guid}")
        logger.error "could not find #{name} for #{app_guid}"
        raise VCAP::Errors::ApiError.new_from_details('StagingError', "#{name} not found for #{app_guid}")
      end

      def logger
        @logger ||= Steno.logger('cc.missing_blob_handler')
      end
    end
  end
end
