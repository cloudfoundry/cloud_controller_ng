require 'presenters/v3/job_presenter'

module V3
  class JobsController < ApplicationController
    def show
      job = VCAP::CloudController::PollableJobModel.find(guid: params[:guid])
      job_not_found! unless job

      render status: :ok, json: Presenters::V3::JobPresenter.new(job)
    end

    private

    def job_not_found!
      resource_not_found!(:job)
    end
  end
end
