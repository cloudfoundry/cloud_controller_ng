# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class User < Sequel::Model
    many_to_many      :organizations
    many_to_many      :app_spaces

    default_order_by  :email

    export_attributes :id, :email, :admin, :active, :organization_ids,
                      :app_space_ids, :created_at, :updated_at

    import_attributes :email, :admin, :active, :password,
                      :organization_ids, :app_space_ids

    def admin?
      admin
    end

    def active?
      active
    end

    def validate
      validates_presence :email
      validates_presence :crypted_password
      validates_email    :email
      validates_unique   :email
    end

    def email=(email)
      email = email.downcase.strip if email
      super(email)
    end

    def password=(unencrypted_password)
      # nil is a valid argument to bcrypt::pw.create, hence the explict
      # nil check
      return if unencrypted_password.nil?
      self.crypted_password = BCrypt::Password.create(unencrypted_password)
    end
  end
end
