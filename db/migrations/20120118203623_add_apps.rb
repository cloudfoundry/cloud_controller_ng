# Copyright (c) 2009-2012 VMware, Inc.

# NOTE: the non-relationship oriented fields in this migration
# are laregly placeholders.  We're going to make an explic pass
# over app state managment once the hierarchical flow is in place.

Sequel.migration do
  change do
    create_table :apps do
      primary_key :id

      String :name,              :null => false

      # environment provided by the developer.
      # does not include environment from service
      # bindings.  those get merged from the bound
      # services
      String :environment_json

      # quota settings
      #
      # FIXME: these defaults are going to move out of here and into
      # the upper layers so that they are more easily run-time configurable
      #
      # This *MUST* be moved because we have to know up at the controller
      # what the actual numbers are going to be so that we can
      # send the correct billing events to the "money maker"
      Integer :memory,           :default => 256
      Integer :instances,        :default => 0
      Integer :file_descriptors, :default => 256
      Integer :disk_quota,       :default => 2048

      # app state
      # TODO: this is a place holder
      String :state,             :null => false, :default => 'STOPPED'

      # package state
      # TODO: this is a place holder
      String :package_state,     :null => false, :default => 'PENDING'
      String :package_hash

      # TODO: sort out the legacy cc fields of metadata and run_count

      foreign_key :app_space_id, :app_spaces, :null => false
      foreign_key :runtime_id,   :runtimes,   :null => false
      foreign_key :framework_id, :frameworks, :null => false

      Timestamp :created_at,     :null => false
      Timestamp :updated_at

      index [:app_space_id, :name], :unique => true
    end
  end
end
