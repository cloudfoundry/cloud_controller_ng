def get_column_definition(table, column)
  fetch("SHOW FULL COLUMNS FROM `#{table}`;").all.find { |c| c[:Field] == column }
end

def verify_no_other_modification(definition_before, definition_after)
  definition_after.each do |key, value|
    raise "Column definition '#{key}' was changed from '#{definition_before[key]}' to '#{value}'" unless value == definition_before[key]
  end
end

Sequel.migration do
  up do
    if foreign_key_list(:apps).none? { |fk| fk[:name] == :fk_apps_droplet_guid }
      self[:apps].exclude(droplet_guid: self[:droplets].select(:guid)).exclude(droplet_guid: nil).update(droplet_guid: nil)

      if database_type == :mysql
        # Ensure that the collation of the foreign key column (apps.droplet_guid) matches the referenced column (droplets.guid)
        guid_definition = get_column_definition('droplets', 'guid')
        droplet_guid_definition = get_column_definition('apps', 'droplet_guid')

        unless droplet_guid_definition[:Collation] == guid_definition[:Collation]
          run("ALTER TABLE `apps` MODIFY COLUMN `droplet_guid` #{droplet_guid_definition[:Type]} COLLATE #{guid_definition[:Collation]};")

          changed_droplet_guid_definition = get_column_definition('apps', 'droplet_guid')
          raise 'Collation was not changed!' unless changed_droplet_guid_definition[:Collation] == guid_definition[:Collation]

          verify_no_other_modification(droplet_guid_definition.except(:Collation), changed_droplet_guid_definition.except(:Collation))
        end
      end

      alter_table :apps do
        add_foreign_key [:droplet_guid], :droplets, key: :guid, name: :fk_apps_droplet_guid
      end
    end
  end

  down do
    if foreign_key_list(:apps).any? { |fk| fk[:name] == :fk_apps_droplet_guid }
      alter_table :apps do
        drop_foreign_key [:droplet_guid], name: :fk_apps_droplet_guid
      end
    end
  end
end
