module VCAP::CloudController
  class SystemAuditUser
    class << self
      def guid
        'system'
      end

      def email
        guid
      end
    end
  end
end
