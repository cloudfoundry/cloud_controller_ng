require 'cloud_controller/diego/lifecycles/lifecycles'

Sequel.migration do
  up do
    add_column :buildpacks, :lifecycle, String, size: 16, if_not_exists: true, default: VCAP::CloudController::Lifecycles::BUILDPACK
  end

  down do
    drop_column :buildpacks, :lifecycle, if_exists: true
  end
end
