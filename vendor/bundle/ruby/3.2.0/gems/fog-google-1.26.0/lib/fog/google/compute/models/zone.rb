module Fog
  module Google
    class Compute
      class Zone < Fog::Model
        identity :name

        attribute :creation_timestamp, :aliases => "creationTimestamp"
        attribute :deprecated
        attribute :description
        attribute :id
        attribute :kind
        attribute :region
        attribute :self_link, :aliases => "selfLink"
        attribute :status

        UP_STATE = "UP".freeze
        DOWN_STATE = "DOWN".freeze

        def up?
          status == UP_STATE
        end
      end
    end
  end
end
