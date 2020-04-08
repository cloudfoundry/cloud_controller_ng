require 'messages/base_message'
require 'models/helpers/process_types'

module VCAP::CloudController
  class RouteMappingsUpdateMessage < BaseMessage
    register_allowed_keys [:weight]

    validates_with NoAdditionalKeysValidator
    validates_numericality_of :weight, only_integer: true, allow_nil: true,
                                       greater_than_or_equal_to: 1,
                                       less_than_or_equal_to: 128,
                                       message: '%<value>i must be an integer between 1 and 128'
  end
end
