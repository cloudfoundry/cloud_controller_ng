module VCAP::CloudController
  class SpaceUpdateIsolationSegment
    class InvalidSpace < StandardError; end
    class InvalidRelationship < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def update(space, org, message)
      isolation_segment_guid = message.isolation_segment_guid
      if isolation_segment_guid
        isolation_segment = IsolationSegmentModel.where(guid: isolation_segment_guid).first
        raise_invalid_relationship! unless isolation_segment

        entitled_iso_segs = org.isolation_segment_guids
        raise_invalid_relationship! unless entitled_iso_segs.include?(isolation_segment_guid)
      end

      space.db.transaction do
        space.lock!

        space.isolation_segment_guid = isolation_segment_guid ? isolation_segment_guid : nil
        space.save

        Repositories::SpaceEventRepository.new.record_space_update(
          space,
          @user_audit_info,
          message.audit_hash
        )
      end

      space
    rescue Sequel::ValidationFailed => e
      raise InvalidSpace.new(e.message)
    end

    private

    def raise_invalid_relationship!
      raise InvalidRelationship.new
    end
  end
end
