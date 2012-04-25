# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table(:app_spaces_users) do
      foreign_key :app_space_id, :app_spaces, :null => false
      foreign_key :user_id, :users

      index [:app_space_id, :user_id], :unique => true
    end
  end
end
