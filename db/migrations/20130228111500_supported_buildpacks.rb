# Copyright (c) 2011-2013 Uhuru Software, Inc.

Sequel.migration do

  change do

    create_table :supported_buildpacks do
      VCAP::Migration.common(self)

      String :name,         :null => false, :case_insensitive => true
      String :description,  :null => false
      String :buildpack,    :null => false
      String :support_url,  :null => false
    end

  end
end
