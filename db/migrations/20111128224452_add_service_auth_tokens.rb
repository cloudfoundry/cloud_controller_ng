# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :service_auth_tokens do
      primary_key :id

      String :label,          :null => false
      String :provider,       :null => false
      String :crypted_token,  :null => false

      Timestamp :created_at,  :null => false
      Timestamp :updated_at

      index [:label, :provider], :unique => true
    end
  end
end
