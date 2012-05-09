# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :User do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :id,            :exclude_in => :update
      to_many   :organizations
      to_many   :app_spaces
      attribute :admin,         Message::Boolean
    end

    query_parameters :app_space_id, :organization_id

    def self.translate_validation_exception(e, attributes)
      id_errors = e.errors.on(:id)
      if id_errors && id_errors.include?(:unique)
        UaaIdTaken.new(attributes["id"])
      else
        UserInvalid.new(e.errors.full_messages)
      end
    end
  end
end
