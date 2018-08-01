module VCAP::CloudController
  module Dea
    module SubSystem
      class << self
        attr_reader :hm9000_respondent, :dea_respondent

        def setup!(message_bus)
          Client.run

          LegacyBulk.register_subscription

          @hm9000_respondent = HM9000::Respondent.new(Client, message_bus)
          @hm9000_respondent.handle_requests

          @dea_respondent = Respondent.new(message_bus)
          @dea_respondent.start
        end
      end
    end
  end
end
