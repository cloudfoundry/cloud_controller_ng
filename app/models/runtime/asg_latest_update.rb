module VCAP::CloudController
  class AsgLatestUpdate
    class AsgTimestamp < Sequel::Model
      plugin :microsecond_timestamp_precision
    end
    private_constant :AsgTimestamp

    def self.renew
      old_update = AsgTimestamp.first
      if old_update
        old_update.update(last_update: Sequel::CURRENT_TIMESTAMP)
      else
        AsgTimestamp.create(last_update: Sequel::CURRENT_TIMESTAMP)
      end
    end

    def self.last_update
      AsgTimestamp.first&.last_update || Time.at(0, in: 'utc')
    end
  end
end
