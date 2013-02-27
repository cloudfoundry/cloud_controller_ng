# Copyright (c) 2009-2013 VMware, Inc.
require "securerandom"

Sequel.migration do
  change do
    create_table :stacks do
      VCAP::Migration.common(self)

      String :name, :null => false, :case_insenstive => true
      String :description, :null => false

      index :name, :unique => true
    end

    # Create single stack to be able to
    # set existing apps to use it; otherwise,
    # we cannot add non_null constraint on apps.stack_id.
    lucid64_stack_id = self[:stacks].insert(
      :guid => SecureRandom.uuid,
      :name => "lucid64",
      :description => "Ubuntu 10.04 on x86-64",
      :created_at => Time.now.to_i,
    )

    alter_table :apps do
      add_column :stack_id, Integer
      add_foreign_key [:stack_id], :stacks, :name => :fk_apps_stack_id
    end

    self[:apps].update(
      :stack_id => lucid64_stack_id,
    )

    alter_table :apps do
      set_column_not_null :stack_id
    end
  end
end
