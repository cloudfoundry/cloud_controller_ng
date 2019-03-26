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
    end
  end
end
