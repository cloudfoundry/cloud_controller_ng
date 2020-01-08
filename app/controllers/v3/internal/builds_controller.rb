require 'messages/internal_build_update_message'

class Internal::BuildsController < ApplicationController
  def update
    unauthorized! unless permission_queryer.can_write_globally? # TODO: more specific scope!

    build = BuildModel.find(guid: params[:guid])
    resource_not_found!(:build) unless build

    message = VCAP::CloudController::InternalBuildUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    if message.state == VCAP::CloudController::BuildModel::FAILED_STATE
      build.fail_to_stage!('StagerError', message.error)
    else
      build.mark_as_staged
      build.save_changes
    end

    render status: :ok, json: Presenters::V3::BuildPresenter.new(build)
  end
end
