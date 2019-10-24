require 'messages/update_environment_variables_message'
require 'presenters/v3/environment_variable_group_presenter'
require 'actions/environment_variable_group_update'

class EnvironmentVariableGroupsController < ApplicationController
  def show
    if hashed_params[:name] == 'staging'
      env_group = EnvironmentVariableGroup.staging
    elsif hashed_params[:name] == 'running'
      env_group = EnvironmentVariableGroup.running
    end

    environment_variable_group_not_found! unless env_group

    render status: :ok, json: Presenters::V3::EnvironmentVariableGroupPresenter.new(env_group)
  end

  def update
    message = VCAP::CloudController::UpdateEnvironmentVariablesMessage.for_env_var_group(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    unauthorized! unless permission_queryer.can_write_globally?

    if hashed_params[:name] == 'staging'
      env_group = EnvironmentVariableGroup.staging
    elsif hashed_params[:name] == 'running'
      env_group = EnvironmentVariableGroup.running
    end

    environment_variable_group_not_found! unless env_group

    env_group = EnvironmentVariableGroupUpdate.new.patch(env_group, message)

    render status: :ok, json: Presenters::V3::EnvironmentVariableGroupPresenter.new(env_group)
  rescue EnvironmentVariableGroupUpdate::EnvironmentVariableGroupTooLong
    unprocessable!('Environment variable group is too large. Specify fewer variables or reduce key/value lengths.')
  end

  private

  def environment_variable_group_not_found!
    resource_not_found!(:environment_variable_group)
  end
end
