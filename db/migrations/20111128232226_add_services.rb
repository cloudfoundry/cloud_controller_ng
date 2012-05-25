# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :services do
      primary_key :id
      String :guid, :null => false, :index => true

      String :label,          :null => false, :index => true
      String :provider,       :null => false
      String :url,            :null => false
      String :type,           :null => false
      String :description,    :null => false
      String :version,        :null => false

      String :info_url
      String :acls
      Integer :timeout
      Boolean :active, :default => false

      Timestamp :created_at, :null => false
      Timestamp :updated_at

      index [:label, :provider], :unique => true
    end
  end
end
