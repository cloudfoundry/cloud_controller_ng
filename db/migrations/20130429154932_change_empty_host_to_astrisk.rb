# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do

  change do
    run "update routes set host = '*' where host = ''"
    alter_table :routes do
      set_column_type :host, String, :case_insensitive => true
      add_constraint :routes_host_not_empty, ~{:host => ''}
    end

    alter_table :service_bindings do
      set_column_allow_null :gateway_name
      set_column_default :gateway_name, nil
    end
  end
end
