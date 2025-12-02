require "fog/core/model"

module Fog
  module Google
    class SQL
      ##
      # A Google Cloud SQL service flag resource
      #
      # @see https://cloud.google.com/sql/docs/mysql/admin-api/v1beta4/flags
      class Flag < Fog::Model
        identity :name

        attribute :allowed_string_values, :aliases => "allowedStringValues"
        attribute :applies_to, :aliases => "appliesTo"
        attribute :kind
        attribute :max_value, :aliases => "maxValue"
        attribute :min_value, :aliases => "minValue"
        attribute :requires_restart, :aliases => "requiresRestart"
        attribute :type
      end
    end
  end
end
