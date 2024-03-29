module VCAP::CloudController
  class OrderByMapper
    class << self
      def from_param(order_by)
        first_character = order_by[0]

        if user_provided_direction?(first_character)
          order_by1 = remove_prefix(order_by)
          order_direction = prefix_to_direction(first_character)
        else
          order_by1 = order_by
          order_direction = nil
        end

        [order_by1, order_direction]
      end

      def to_param_hash(pagination_options)
        return {} unless pagination_options.ordering_configured?

        prefix = direction_to_prefix(pagination_options.order_direction)
        { order_by: "#{prefix}#{pagination_options.order_by}" }
      end

      private

      PREFIX_TO_DIRECTION = { '+' => 'asc', '-' => 'desc' }.freeze
      DIRECTION_TO_PREFIX = PREFIX_TO_DIRECTION.invert

      def user_provided_direction?(first_character)
        PREFIX_TO_DIRECTION.key?(first_character)
      end

      def prefix_to_direction(first_character)
        PREFIX_TO_DIRECTION[first_character]
      end

      def direction_to_prefix(order_direction)
        DIRECTION_TO_PREFIX[order_direction]
      end

      def remove_prefix(order_by)
        order_by[1..]
      end
    end
  end
end
