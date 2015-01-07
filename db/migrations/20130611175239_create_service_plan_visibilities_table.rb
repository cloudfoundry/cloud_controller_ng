Sequel.migration do
  change do
    create_table :service_plan_visibilities do
      VCAP::Migration.common(self, :spv)
      Integer :service_plan_id, null: false
      Integer :organization_id, null: false
      index [:organization_id, :service_plan_id], unique: true

      foreign_key [:service_plan_id], :service_plans, name: :fk_service_plan_visibilities_service_plan_id
      foreign_key [:organization_id], :organizations, name: :fk_service_plan_visibilities_organization_id
    end
  end
end
