module VCAP::CloudController
  class StagingSecurityGroupsSpace < Sequel::Model
    many_to_one :security_group, key: :staging_security_group_id
    many_to_one :space
  end
end
