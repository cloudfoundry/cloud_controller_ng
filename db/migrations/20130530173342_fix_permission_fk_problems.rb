# Copyright (c) 2009-2012 VMware, Inc.

# Helper method to cleanup erroneous fk columns in permission tables
def cleanup_permission_table(name, permission)
  name = name.to_s
  join_table = "#{name.pluralize}_#{permission}".to_sym
  id_attr = "#{name}_id".to_sym
  fk_name = "#{name}_fk".to_sym
  new_fk_name = "#{join_table}_#{name}_fk".to_sym
  new_fk_user = "#{join_table}_user_fk".to_sym
  table = name.pluralize.to_sym
  # rename based on finding an fk that references one of the bad columns
  foreign_key_list(join_table).each do |fk|
    if (fk[:columns] == [fk_name])
      alter_table join_table do
        drop_constraint fk[:name], type: :foreign_key
        drop_column fk_name
        add_foreign_key [id_attr], table, name: new_fk_name
      end
    elsif (fk[:columns] == [:user_fk])
      alter_table join_table do
        drop_constraint fk[:name], type: :foreign_key
        drop_column :user_fk
        add_foreign_key [:user_id], :users, name: new_fk_user
      end
    end
  end
end

Sequel.migration do
  up do
    [:users, :managers, :billing_managers, :auditors].each do |perm|
      cleanup_permission_table(:organization, perm)
    end

    [:developers, :managers, :auditors].each do |perm|
      cleanup_permission_table(:space, perm)
    end

    foreign_key_list(:app_events).each do |fk|
      if (fk[:columns] == [:fk_app_events_app_id])
        alter_table :app_events do
          drop_constraint fk[:name], type: :foreign_key
          drop_column :fk_app_events_app_id
          add_foreign_key [:app_id], :apps, name: :fk_app_events_app_id
        end
      end
    end
  end

  down do
    raise Sequel::Error.new('This migration cannot be reversed.')
  end
end
