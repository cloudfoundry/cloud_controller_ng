# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    [:service_instances, :service_bindings].each do |table|
      rename_column table, :gateway_data, :gateway_data_old
      add_column table, :gateway_data, String
      self[table].each do |r|
        self[table].filter(:id=>r[:id]).
          update(:gateway_data =>
                 Yajl::Encoder.encode(eval(r[:gateway_data_old])))
      end
      drop_column table, :gateway_data_old
    end
  end
end
