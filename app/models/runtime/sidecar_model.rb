module VCAP::CloudController
  class SidecarModel < Sequel::Model(:sidecars)
    many_to_one :app,
      class: 'VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true

    one_to_many :sidecar_process_types,
      class: 'VCAP::CloudController::SidecarProcessTypeModel',
      key: :sidecar_guid,
      primary_key: :guid

    def process_types
      sidecar_process_types.map(&:type).sort
    end

    def validate
      validates_unique [:app_guid, :name], message: Sequel.lit("Sidecar with name '#{name}' already exists for given app")
    end
  end
end
