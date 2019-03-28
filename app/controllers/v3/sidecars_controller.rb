require 'controllers/v3/mixins/app_sub_resource'
require 'messages/sidecar_create_message'
require 'actions/sidecar_create'
require 'presenters/v3/sidecar_presenter'

class SidecarsController < ApplicationController
  include AppSubResource

  def create
    app, space, org = AppFetcher.new.fetch(hashed_params[:guid])
    resource_not_found!(:app) unless app && permission_queryer.can_read_from_space?(space.guid, org.guid)
    unauthorized! unless permission_queryer.can_write_to_space?(space.guid)

    message = SidecarCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    sidecar = SidecarCreate.create(app.guid, message)

    render status: 201, json: Presenters::V3::SidecarPresenter.new(sidecar)
  rescue SidecarCreate::InvalidSidecar => e
    unprocessable!(e.message)
  end

  def show
    sidecar = SidecarModel.find(guid: hashed_params[:guid])
    resource_not_found!(:sidecar) unless sidecar
    app = sidecar.app
    resource_not_found!(:sidecar) unless permission_queryer.can_read_from_space?(app.space.guid, app.space.organization.guid)

    render status: 200, json: Presenters::V3::SidecarPresenter.new(sidecar)
  end
end
