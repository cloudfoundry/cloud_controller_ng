Sequel.migration do
  change do
    problematic_deployments = self[:deployments].where(
      Sequel.lit("status_value IS NULL OR TRIM(status_value) = '' OR state = 'FAILING' OR state = 'FAILED'")
    )

    problematic_deployments.each do |deployment|
      fields_to_update = {}
      case deployment[:state]
      when 'DEPLOYED', 'CANCELED'
        fields_to_update[:status_value] = 'FINALIZED'
      when 'FAILED'
        fields_to_update[:state] = 'DEPLOYED'
        fields_to_update[:status_value] = 'FINALIZED'
      when 'DEPLOYING', 'CANCELING'
        fields_to_update[:status_value] = 'DEPLOYING'
      when 'FAILING'
        fields_to_update[:state] = 'DEPLOYING'
        fields_to_update[:status_value] = 'DEPLOYING'
      end

      self[:deployments].where(guid: deployment[:guid]).update(fields_to_update) unless fields_to_update.empty?
    end
  end
end
