module VCAP::CloudController
  module Repositories
    class OrphanedBlobEventRepository
      def self.record_delete(directory_key, blob_key)
        Event.create(
          type:              'blob.remove_orphan',
          actor:             'system',
          actor_type:        'system',
          actor_name:        'system',
          actor_username:    'system',
          actee:             "#{directory_key}/#{blob_key}",
          actee_type:        'blob',
          actee_name:        '',
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          {},
          space_guid:        '',
          organization_guid: ''
        )
      end
    end
  end
end
