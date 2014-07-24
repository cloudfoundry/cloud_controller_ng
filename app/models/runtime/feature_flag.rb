module VCAP::CloudController
  class FeatureFlag < Sequel::Model

    export_attributes :name, :enabled
    import_attributes :name, :enabled

    def validate
      validates_presence :name
      validates_unique :name
      validates_presence :enabled
    end
  end
end
