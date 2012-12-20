# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :service_plans do
      add_column :free, TrueClass
    end

    self[:service_plans].all do |plan|
      free = false
      free = true if plan[:name] =~ /^d1[0-9][0-9]$/i
      self[:service_plans].filter(:id => plan[:id]).update(:free => free)
    end

    alter_table :service_plans do
      set_column_not_null :free
    end
  end
end
