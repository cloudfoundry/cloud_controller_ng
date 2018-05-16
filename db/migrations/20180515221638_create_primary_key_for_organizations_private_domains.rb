require File.expand_path('../../helpers/change_primary_key', __FILE__)

Sequel.migration do
  up do
    add_primary_key_to_table(:organizations_private_domains, :organizations_private_domains_pk)
  end

  down do
    remove_primary_key_from_table(:organizations_private_domains,
                                  :organizations_private_domains_pkey,
                                  :organizations_private_domains_pk)
  end
end
