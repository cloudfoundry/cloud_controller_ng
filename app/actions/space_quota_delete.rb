module VCAP::CloudController
  class SpaceQuotaDeleteAction
    def delete(space_quotas)
      space_quotas.each do |space_quota|
        SpaceQuotaDefinition.db.transaction do
          space_quota.destroy
        end
      end
      []
    end
  end
end
