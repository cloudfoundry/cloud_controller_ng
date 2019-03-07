require 'messages/domain_create_message'
require 'presenters/v3/domain_presenter'
require 'actions/domain_create'

class DomainsController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?
    message = DomainCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    domain = DomainCreate.new.create(message: message)

    render status: :created, json: Presenters::V3::DomainPresenter.new(domain)
  rescue DomainCreate::Error => e
    unprocessable!(e)
  end
end
