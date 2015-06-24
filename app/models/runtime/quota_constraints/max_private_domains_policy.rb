class MaxPrivateDomainsPolicy
  def initialize(quota_defintion, private_domain_counter)
    @quota_definition = quota_defintion
    @private_domain_counter = private_domain_counter
  end

  def allow_more_private_domains?(number_of_new_private_domains)
    return true if @quota_definition.total_private_domains == -1

    existing_total_private_domains = @private_domain_counter.count
    @quota_definition.total_private_domains >= (existing_total_private_domains + number_of_new_private_domains)
  end
end
