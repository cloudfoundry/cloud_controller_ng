module VCAP::CloudController
  class EffectiveSpaceQuotaCalculator
    def self.calculate(space)
      space_quota = space.space_quota_definition
      org_quota = space.organization.quota_definition

      quota_attributes = VCAP::CloudController::QuotaDefinition.columns - %i[id guid created_at updated_at name] # remove attributes not needed in effective quota
      effective_quota_struct = Struct.new(*quota_attributes, keyword_init: true)

      effective_quota = {}

      quota_attributes.each do |col|
        effective_quota[col] = if space_quota.nil? || !space_quota.respond_to?(col)
                                 org_quota.send(col)
                               elsif col == :non_basic_services_allowed
                                 space_quota.non_basic_services_allowed && org_quota.non_basic_services_allowed
                               else
                                 calculate_limit(space_quota.send(col), org_quota.send(col))
                               end
      end

      effective_quota_struct.new(effective_quota)
    end

    def self.calculate_limit(space_limit, org_limit)
      return org_limit if space_limit == -1
      return space_limit if org_limit == -1

      [space_limit, org_limit].min
    end
  end
end
