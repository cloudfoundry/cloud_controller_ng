module VCAP::CloudController
  class SecurityGroupUnapply
    class Error < ::StandardError
    end

    class << self
      def unapply_running(security_group, space)
        unapply(security_group, space, :running)
      end

      private

      def unapply(security_group, space, staging_or_running)
        if staging_or_running == :running
          SecurityGroup.db.transaction do
            security_group.remove_space(space)
          end
        end
      rescue Sequel::ValidationFailed => e
        raise Error.new(e.message)
      end
    end
  end
end
