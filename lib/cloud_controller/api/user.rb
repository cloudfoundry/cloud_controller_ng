# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  rest_controller :User do
    grant_access do
      full Role::CFAdmin
    end

    define_attributes do
      attribute :email,                Message::EMAIL
      attribute :password,             String,    :exclude_in => :response
      to_many   :organizations
      to_many   :app_spaces
      attribute :admin,                Message::Boolean
    end

    def self.translate_validation_exception(e, attributes)
      email_errors = e.errors.on(:email)
      if email_errors && email_errors.include?(:unique)
        EmailTaken.new(attributes[:email])
      else
        UserInvalid.new(e.errors.full_messages)
      end
    end
  end
end
