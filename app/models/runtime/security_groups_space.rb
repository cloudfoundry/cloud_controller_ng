module VCAP::CloudController
  class SecurityGroupsSpace < Sequel::Model

    many_to_one :security_group
    many_to_one :space
  end
end
