module VCAP::CloudController
  module Diego
    class StagedAppsQuery
      def initialize(batch_size, last_id)
        @batch_size = batch_size
        @last_id = last_id
      end

      def all
        App.
          eager(:current_saved_droplet, :space, :stack, :service_bindings, {:routes => :domain}).
          where("apps.id > ?", @last_id).
          where("deleted_at IS NULL").
          where(state: "STARTED").
          where(package_state: "STAGED").
          where(diego: true).
          order(:id).
          limit(@batch_size).
          all
      end
    end
  end
end
