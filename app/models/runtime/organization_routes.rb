class OrganizationRoutes
  def initialize(organization)
    @organization = organization
  end

  delegate :count, to: :dataset

  private

  def dataset
    VCAP::CloudController::Route.dataset.join(:spaces, id: :space_id).
      where(spaces__organization_id: @organization.id)
  end
end
