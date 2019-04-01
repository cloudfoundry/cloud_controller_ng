require File.expand_path('../../helpers/change_primary_key', __FILE__)

Sequel.migration do
  up do
    add_primary_key_to_table(:staging_security_groups_spaces, :staging_security_groups_spaces_pk)
  end

  down do
    remove_primary_key_from_table(:staging_security_groups_spaces,
                                  :staging_security_groups_spaces_pkey,
                                  :staging_security_groups_spaces_pk)
  end
end
