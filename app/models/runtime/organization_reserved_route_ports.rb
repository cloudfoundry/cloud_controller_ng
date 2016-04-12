class OrganizationReservedRoutePorts
  def initialize(organization)
    @organization = organization
  end

  def count
    dataset.count
  end

  private

  def dataset
    VCAP::CloudController::Route.dataset.join(:spaces, id: :space_id).
      where(spaces__organization_id: @organization.id) { port > 0 }
  end
end
