Sequel.migration do
  change do
    deployments_without_status_value = self[:deployments].where(
      Sequel.lit("status_value IS NULL OR TRIM(status_value) = ''")
    )

    deployments_without_status_value.each do |deployment|
      deployment_guid = deployment[:guid]
      state = deployment[:state]

      fields_to_update = {}
      fields_to_update[:status_value] = 'FINALIZED' if ['DEPLOYED', 'CANCELED', 'FAILED'].include?(state)
      fields_to_update[:status_value] = 'DEPLOYING' if ['DEPLOYING', 'CANCELING', 'FAILING'].include?(state)

      self[:deployments].where(guid: deployment_guid).update(fields_to_update) unless fields_to_update.empty?
    end
  end
end
