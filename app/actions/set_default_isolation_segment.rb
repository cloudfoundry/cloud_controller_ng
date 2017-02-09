module VCAP::CloudController
  class SetDefaultIsolationSegment
    class InvalidOrg < StandardError; end
    class InvalidRelationship < StandardError; end

    def set(org, isolation_segment, message)
      iso_seg_guid = message.default_isolation_segment_guid
      if iso_seg_guid
        invalid_relationship! unless isolation_segment

        entitled_iso_segs = org.isolation_segment_guids
        invalid_relationship! unless entitled_iso_segs.include?(iso_seg_guid)
      end

      org.db.transaction do
        org.lock!

        org.default_isolation_segment_guid = iso_seg_guid if message.requested?(:data)

        org.save
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidOrg.new(e.message)
    end

    private

    def invalid_relationship!
      raise InvalidRelationship.new
    end
  end
end
