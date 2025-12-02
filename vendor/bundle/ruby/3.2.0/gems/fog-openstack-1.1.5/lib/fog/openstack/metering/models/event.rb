require 'fog/openstack/models/model'

module Fog
  module OpenStack
    class Metering
      class Event < Fog::OpenStack::Model
        identity :message_id

        attribute :event_type
        attribute :generated
        attribute :raw
        attribute :traits
      end
    end
  end
end
