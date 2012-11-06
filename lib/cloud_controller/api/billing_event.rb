# Copyright (c) 2009-2011 VMware, Inc.

module VCAP::CloudController
  rest_controller :BillingEvent do
    serialization RestController::EntityOnlyObjectSerialization

    permissions_required do
      read Permissions::CFAdmin
    end
  end
end
