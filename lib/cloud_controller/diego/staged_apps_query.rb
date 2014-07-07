module VCAP::CloudController
  module Diego
    class StagedAppsQuery
      def initialize(batch_size, last_id)
        @batch_size = batch_size
        @last_id = last_id
      end

      def all
        App.
          where("id > ?", @last_id).
          where("deleted_at IS NULL").
          where("state = ?", "STARTED").
          where("package_state = ?", "STAGED").
          order(:id).
          limit(@batch_size).
          to_a
      end
    end
  end
end
