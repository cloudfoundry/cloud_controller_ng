require 'messages/route_create_message'
require 'presenters/v3/route_presenter'
require 'actions/route_create'

class RoutesController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = RouteCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = Space.find(guid: message.space_guid)
    domain = Domain.find(guid: message.domain_guid)
    unprocessable_space! unless space
    unprocessable_domain! unless domain

    route = RouteCreate.new.create(message: message, space: space, domain: domain)

    render status: :created, json: Presenters::V3::RoutePresenter.new(route)
  rescue RouteCreate::Error => e
    unprocessable!(e)
  end

  private

  def unprocessable_space!
    unprocessable!('Invalid space. Ensure that the space exists and you have access to it.')
  end

  def unprocessable_domain!
    unprocessable!('Invalid domain. Ensure that the domain exists and you have access to it.')
  end
end
