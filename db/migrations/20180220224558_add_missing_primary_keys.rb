Sequel.migration do
  change do
    # This migration originally added primary keys to ten join tables.
    # It was split into ten separate migrations to make these operations more atomic,
    # and less likely to cause a deadlock during migration - as seen in
    # [this issue](https://github.com/cloudfoundry/cloud_controller_ng/issues/1133)
  end
end
