module VCAP::CloudController
  class UserUpdate
    class InvalidUser < StandardError
    end

    def initialize
      @logger = Steno.logger('cc.action.user_update')
    end

    def update(user:, message:)
      User.db.transaction do
        MetadataUpdate.update(user, message)
      end

      @logger.info("Finished updating metadata on user #{user.guid}")

      user
    rescue Sequel::ValidationFailed => e
      raise InvalidUser.new(e.message)
    end
  end
end
