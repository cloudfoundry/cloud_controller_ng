# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceBase < BillingEvent
    def validate
      super
    end
  end
end
