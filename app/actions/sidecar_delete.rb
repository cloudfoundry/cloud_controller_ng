module VCAP::CloudController
  class SidecarDelete
    class << self
      def delete(sidecars)
        sidecars.delete
      end

      def delete_for_app(guid)
        SidecarModel.where(app_guid: guid).delete
      end
    end
  end
end
