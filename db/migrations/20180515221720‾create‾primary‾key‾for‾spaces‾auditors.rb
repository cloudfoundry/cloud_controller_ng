require File.expand_path('../../helpers/change_primary_key', __FILE__)

Sequel.migration do
  up do
    add_primary_key_to_table(:spaces_auditors, :spaces_auditors_pk)
  end

  down do
    remove_primary_key_from_table(:spaces_auditors,
                                  :spaces_auditors_pkey,
                                  :spaces_auditors_pk)
  end
end
