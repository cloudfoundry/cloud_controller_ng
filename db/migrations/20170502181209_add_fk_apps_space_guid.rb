# If this migration fails, it is likely because the environment has an app without an associated space.
# To resolve this issue, update each app's space_guid to the guid of an existing space.
#
# 1) Find the offending apps' guids: SELECT guid FROM apps WHERE space_guid NOT IN (SELECT guid FROM spaces);
# 2) Get the guids for the spaces you want the apps to be in: SELECT guid FROM spaces WHERE name='<space_name>';
# 3) Update each app's space_guid: UPDATE apps SET space_guid = '<space_guid>' WHERE guid='<app_guid>';
# 4) You may now delete the app and/or space if you wish
# 5) Proceed with the deploy as usual

Sequel.migration do
  change do
    alter_table(:apps) do
      add_foreign_key [:space_guid], :spaces, key: :guid, name: :fk_apps_space_guid
    end
  end
end
