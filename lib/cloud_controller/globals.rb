module VCAP::CloudController
  class Globals
    def initialize(config, message_bus)
      @config = config
      @message_bus = message_bus
    end

    def setup!
      DeaClient.run
      AppObserver.run

      LegacyBulk.register_subscription

      hm9000_respondent = HM9000Respondent.new(DeaClient, @message_bus)
      hm9000_respondent.handle_requests

      VCAP::CloudController.dea_respondent = DeaRespondent.new(@message_bus)
      VCAP::CloudController.dea_respondent.start
    end
  end
end
