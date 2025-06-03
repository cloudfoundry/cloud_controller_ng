module VCAP::CloudController
  class AsgLatestUpdate
    class AsgTimestamp < Sequel::Model
      plugin :microsecond_timestamp_precision
    end
    private_constant :AsgTimestamp

    def self.renew
      old_update = AsgTimestamp.first
      if old_update
        old_update.update(last_update: Time.now.utc)
      else
        AsgTimestamp.create(last_update: Time.now.utc)
      end
    end

    def self.last_update
      AsgTimestamp.first&.last_update || Time.at(0, in: 'utc')
    end
  end
end
