require 'messages/sidecar_create_message'
require 'actions/sidecar_create'
require 'presenters/v3/sidecar_presenter'

class SidecarsController < ApplicationController
  before_action do
    resource_not_found!(app) unless app && permission_queryer.can_read_from_space?(app.space.guid, app.organization.guid)
  end

  def create
    unauthorized! unless permission_queryer.can_write_to_space?(app.space.guid)

    message = SidecarCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    sidecar = SidecarCreate.create(app.guid, message)

    render status: 201, json: Presenters::V3::SidecarPresenter.new(sidecar)
  rescue SidecarCreate::InvalidSidecar => e
    unprocessable!(e.message)
  end

  private

  def app
    @app ||= AppModel.first(guid: params[:guid])
  end
end
