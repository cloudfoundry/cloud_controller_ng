module VCAP::CloudController
  class SecurityGroupUnapply
    class Error < ::StandardError
    end

    class << self
      def unapply_running(security_group, space)
        unapply(security_group, space, true)
      end

      def unapply_staging(security_group, space)
        unapply(security_group, space, false)
      end

      private

      def unapply(security_group, space, is_running=false)
        if is_running
          SecurityGroup.db.transaction do
            security_group.remove_space(space)
            AsgLatestUpdate.renew
          end
        else
          SecurityGroup.db.transaction do
            security_group.remove_staging_space(space)
            AsgLatestUpdate.renew
          end
        end
      rescue Sequel::ValidationFailed => e
        raise Error.new(e.message)
      end
    end
  end
end
