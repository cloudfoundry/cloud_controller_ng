require 'messages/user_create_message'
require 'actions/user_create'
require 'presenters/v3/user_presenter'

class UsersController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = UserCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    user = UserCreate.new.create(message: message)

    render status: :created, json: Presenters::V3::UserPresenter.new(user)
  rescue UserCreate::Error => e
    unprocessable!(e)
  end
end
