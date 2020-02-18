require 'messages/security_group_create_message'
require 'actions/security_group_create'
require 'presenters/v3/security_group_presenter'

class SecurityGroupsController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = SecurityGroupCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    security_group = SecurityGroupCreate.create(message)

    render status: :created, json: Presenters::V3::SecurityGroupPresenter.new(security_group)
  rescue SecurityGroupCreate::Error => e
    unprocessable!(e)
  end
end
