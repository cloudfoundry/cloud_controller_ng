require 'messages/service_account_create_message'
require 'presenters/v3/service_account_presenter'

class ServiceAccountsController < ApplicationController
  def show
    account = ServiceAccountModel.where(guid: hashed_params[:guid]).first
    resource_not_found!(:service_account) unless account && permission_queryer.can_read_from_space?(account.space.id, account.space.organization_id)

    render status: :ok, json: Presenters::V3::ServiceAccountPresenter.new(account)
  end

  def create
    message = ServiceAccountCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    space = Space.where(guid: message.space_guid).first
    unprocessable!('Space not found') unless space && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    unauthorized! unless permission_queryer.can_write_globally? || space.managers_dataset.where(id: current_user.id).any?
    require_writable_space!(space)

    account = ServiceAccountModel.create(name: message.name, space: space)
    render status: :created, json: Presenters::V3::ServiceAccountPresenter.new(account)
  rescue Sequel::ValidationFailed => e
    raise CloudController::Errors::V3::ApiError.new_from_details('ServiceAccountNameReserved') if e.message.include?('is already reserved')

    unprocessable!(e.message)
  end
end
