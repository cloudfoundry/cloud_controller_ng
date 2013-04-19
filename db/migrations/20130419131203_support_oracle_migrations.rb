# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  up do
    if !self.class.name.match /oracle/i
      schema(:billing_events).each { |column|
        if column[0] == :timestamp
          rename_column(:billing_events, :timestamp, :event_timestamp)
        end
      }
      
      VCAP::Migration.rename_foreign_key(self, :organizations, :fk_organizations_quota_definition_id, :fk_org_quota_definition_id)
      VCAP::Migration.rename_foreign_key(self, :domains, :fk_domains_owning_organization_id, :fk_domains_owning_org_id)
      VCAP::Migration.rename_foreign_key(self, :domains_organizations, :fk_domains_organizations_domain_id, :fk_domains_orgs_domain_id)
      VCAP::Migration.rename_foreign_key(self, :domains_organizations, :fk_domains_organizations_organization_id, :fk_domains_orgs_org_id)
      VCAP::Migration.rename_foreign_key(self, :service_instances, :service_instances_service_plan_id, :svc_instances_service_plan_id)
      VCAP::Migration.rename_foreign_key(self, :service_bindings, :fk_service_bindings_service_instance_id, :fk_sb_service_instance_id)
    end
  end

  down do
    raise Sequel::Error, "This migration cannot be reversed since we don't know if 'timestamp' and the fks were renamed originally."
  end
end