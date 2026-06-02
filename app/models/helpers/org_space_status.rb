module VCAP::CloudController
  module OrgSpaceStatus
    ACTIVE = 'active'.freeze
    SUSPENDED = 'suspended'.freeze
    DELETING = 'deleting'.freeze

    VALID_STATUSES = [ACTIVE, SUSPENDED, DELETING].freeze

    def active?
      status == ACTIVE
    end

    def suspended?
      status == SUSPENDED
    end

    def deleting?
      status == DELETING
    end
  end
end
