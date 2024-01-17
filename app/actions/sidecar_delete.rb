module VCAP::CloudController
  class SidecarDelete
    class << self
      def delete(sidecars)
        Array(sidecars).each do |sidecar|
          sidecar.db.transaction do
            sidecar.lock!
            sidecar.sidecar_process_types.each(&:destroy)
            sidecar.destroy
          end
        end
      end

      def delete_for_app(guid)
        SidecarModel.db.transaction do
          app_sidecars_dataset = SidecarModel.where(app_guid: guid)
          SidecarProcessTypeModel.where(sidecar_guid: app_sidecars_dataset.select(:guid)).delete
          app_sidecars_dataset.delete
        end
      end
    end
  end
end
