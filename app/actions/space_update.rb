module VCAP::CloudController
  class SpaceUpdate
    class InvalidSpace < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.app_update')
    end

    def update(space, isolation_segment_model, message)
      space.db.transaction do
        space.lock!

        space.isolation_segment_guid = isolation_segment_model && isolation_segment_model.guid
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
  end
end
