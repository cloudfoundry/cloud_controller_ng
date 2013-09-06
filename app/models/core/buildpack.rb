module VCAP::CloudController::Models
  class Buildpack < Sequel::Model

    export_attributes :name, :key, :priority

    import_attributes :name, :key, :priority

    def validate
      validates_unique   :name
    end

    def self.user_visibility_filter(user)
      full_dataset_filter
    end
  end
end