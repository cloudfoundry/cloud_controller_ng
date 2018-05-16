require File.expand_path('../../helpers/change_primary_key', __FILE__)

Sequel.migration do
  up do
    add_primary_key_to_table(:spaces_managers, :spaces_managers_pk)
  end

  down do
    remove_primary_key_from_table(:spaces_managers,
                                  :spaces_managers_pkey,
                                  :spaces_managers_pk)
  end
end
