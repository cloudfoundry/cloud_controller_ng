require 'presenters/v3/usage_event_presenter'

class UsageEventsController < ApplicationController
  def show
    usage_event_not_found! unless permission_queryer.can_read_globally?
    usage_event = UsageEvent.first(guid: hashed_params[:guid])
    usage_event_not_found! unless usage_event

    render status: :ok, json: Presenters::V3::UsageEventPresenter.new(usage_event)
  end

  private

  def usage_event_not_found!
    resource_not_found!(:usage_event)
  end
end
