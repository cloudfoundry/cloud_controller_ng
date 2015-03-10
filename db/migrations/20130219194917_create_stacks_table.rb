# Copyright (c) 2009-2013 VMware, Inc.
require 'securerandom'

Sequel.migration do
  change do
    create_table :stacks do
      VCAP::Migration.common(self)

      String :name, null: false, case_insenstive: true
      String :description, null: false

      index :name, unique: true
    end

    alter_table :apps do
      add_column :stack_id, Integer
      add_foreign_key [:stack_id], :stacks, name: :fk_apps_stack_id
    end

    alter_table :apps do
      set_column_not_null :stack_id
    end
  end
end
