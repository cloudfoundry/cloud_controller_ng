# Copyright (c) 2009-2012 VMware, Inc.

# Helper method to rename a foreign key constraint only if the constraint exists
def rename_foreign_key(table, current_name, new_name)
  foreign_key_list(table).each { |fk|
    if fk[:name] && fk[:name] == current_name
      alter_table table do
        drop_constraint current_name, :type => :foreign_key
        add_foreign_key fk[:columns], fk[:table], :name => new_name
      end
    end
  }
end

Sequel.migration do
  up do
    if !self.class.name.match /oracle/i
      schema(:billing_events).each { |column|
        if column[0] == :timestamp
          rename_column(:billing_events, :timestamp, :event_timestamp)
        end
      }

      schema(:crash_events).each { |column|
        if column[0] == :timestamp
          rename_column(:crash_events, :timestamp, :event_timestamp)
        end
      }
      
      rename_foreign_key(:organizations, :fk_organizations_quota_definition_id, :fk_org_quota_definition_id)
      rename_foreign_key(:domains, :fk_domains_owning_organization_id, :fk_domains_owning_org_id)
      rename_foreign_key(:domains_organizations, :fk_domains_organizations_domain_id, :fk_domains_orgs_domain_id)
      rename_foreign_key(:domains_organizations, :fk_domains_organizations_organization_id, :fk_domains_orgs_org_id)
      rename_foreign_key(:service_instances, :service_instances_service_plan_id, :svc_instances_service_plan_id)
      rename_foreign_key(:service_bindings, :fk_service_bindings_service_instance_id, :fk_sb_service_instance_id)
    end
  end

  down do
    raise Sequel::Error, "This migration cannot be reversed since we don't know if 'timestamp' and the fks were renamed originally."
  end
end