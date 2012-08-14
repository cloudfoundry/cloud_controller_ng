# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    rename_column :service_auth_tokens, :crypted_token, :token
  end
end
