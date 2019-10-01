require 'presenters/v3/environment_variable_group_presenter'

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

  private

  def environment_variable_group_not_found!
    resource_not_found!(:environment_variable_group)
  end
end
