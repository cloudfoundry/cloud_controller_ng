require 'cloud_controller/dea/nats_messages/advertisment'

module VCAP::CloudController
  module Dea
    module NatsMessages
      class StagerAdvertisement < Advertisement
        def stager_id
          stats['id']
        end
      end
    end
  end
end
