# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :ServiceAuthToken do
    permissions_required do
      full Permissions::CFAdmin
    end

    define_attributes do
      attribute :label,    String
      attribute :provider, String
      attribute :token,    String,  :exclude_in => :response
    end

    def self.translate_validation_exception(e, attributes)
      label_provider_errors = e.errors.on([:label, :provider])
      if label_provider_errors && label_provider_errors.include?(:unique)
        Errors::ServiceAuthTokenLabelTaken.new("#{attributes["label"]}-#{attributes["provider"]}")
      else
        Errors::ServiceAuthTokenInvalid.new(e.errors.full_messages)
      end
    end
  end
end
