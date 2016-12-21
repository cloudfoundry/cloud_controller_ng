Sequel.migration do
  change do
    create_table :space_quota_definitions do
      VCAP::Migration.common(self, :sqd)

      String :name, null: false
      TrueClass :non_basic_services_allowed, null: false
      Integer :total_services, null: false
      Integer :memory_limit, null: false
      Integer :total_routes, null: false
      Fixnum :instance_memory_limit, null: false, default: -1
      Integer :organization_id, null: false

      foreign_key [:organization_id], :organizations, name: :fk_sqd_organization_id
      index [:organization_id, :name], unique: true, name: :sqd_org_id_index
    end
  end
end
