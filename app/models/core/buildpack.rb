module VCAP::CloudController::Models
  class Buildpack < Sequel::Model

    export_attributes :name, :key

    import_attributes :name, :key

    def validate
      validates_unique   :name
    end
  end
end