# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    # drop null constraint.  Since dropping a constraint isn't portable between
    # databases, we take the following approach
    rename_column :routes, :host, :host_old
    add_column :routes, :host, String, :case_insensitive => true
    self[:routes].each do |r|
      self[:routes].filter(:id => r[:id]).update(:host => r[:host_old])
    end
    drop_column :routes, :host_old
    add_index :routes, [:host, :domain_id], :unique => true
  end
end
