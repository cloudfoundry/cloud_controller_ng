module VCAP::CloudController
  class AppSecurityGroupsSpace < Sequel::Model

    many_to_one :app_security_group
    many_to_one :space
  end
end