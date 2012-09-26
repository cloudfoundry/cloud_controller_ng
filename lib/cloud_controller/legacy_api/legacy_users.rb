# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyUsers < LegacyApiBase
    include VCAP::CloudController::Errors

    def read(email)
      unless SecurityContext.current_user_has_email?(email)
        raise NotAuthorized
      end

      Yajl::Encoder.encode(:email => email,
                           :admin => SecurityContext.current_user_is_admin?)
    end

    def self.setup_routes
      get "/users/:email", :read
    end

    setup_routes
  end
end
