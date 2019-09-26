require 'presenters/v3/event_presenter'

class EventsController < ApplicationController
  def show
    event = readable_event_dataset.first(guid: hashed_params[:guid])
    event_not_found! unless event

    render status: :ok, json: Presenters::V3::EventPresenter.new(event)
  end

  private

  def event_not_found!
    resource_not_found!(:event)
  end

  def readable_event_dataset
    Event.user_visible(current_user, permission_queryer.can_read_globally?)
  end
end
