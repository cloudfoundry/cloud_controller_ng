module VCAP::CloudController
  module Dea
    module SubSystem
      def self.setup!(message_bus)
        Dea::Client.run
        AppObserver.run

        LegacyBulk.register_subscription

        hm9000_respondent = Dea::HM9000::Respondent.new(Dea::Client, message_bus)
        hm9000_respondent.handle_requests

        VCAP::CloudController.dea_respondent = Dea::Respondent.new(message_bus)
        VCAP::CloudController.dea_respondent.start
      end
    end
  end
end
