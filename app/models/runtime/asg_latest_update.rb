module VCAP::CloudController
  class AsgLatestUpdate
    class AsgTimestamp < Sequel::Model
    end
    private_constant :AsgTimestamp

    def self.renew
      old_update = AsgTimestamp.first
      if old_update
        old_update.update(last_update: DateTime.now.utc)
      else
        AsgTimestamp.create(last_update: DateTime.now.utc)
      end
    end

    def self.last_update
      AsgTimestamp.first&.last_update || Time.at(0, in: 'utc').utc
    end
  end
end
