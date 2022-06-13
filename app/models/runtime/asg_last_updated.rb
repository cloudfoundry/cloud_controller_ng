module VCAP::CloudController
  class AsgLatestUpdate < Sequel::Model
    def self.renew
      old_update = AsgLatestUpdate.first
      if old_update
        old_update.update(last_update: DateTime.now)
      else
        AsgLatestUpdate.create(last_update: DateTime.now)
      end
    end

    def self.last_update
      AsgLatestUpdate.first&.last_update || Time.at(0)
    end
  end
end
