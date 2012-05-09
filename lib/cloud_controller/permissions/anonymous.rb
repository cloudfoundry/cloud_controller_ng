# Copyright (c) 2009-2012 VMware Inc.

module VCAP::CloudController::Permissions
  class Anonymous
    def self.granted_to?(user)
      user.nil?
    end

    VCAP::CloudController::Permissions::register self
  end
end
