require 'presenters/v3/app_usage_snapshot_presenter'
require 'presenters/v3/app_usage_snapshot_chunk_presenter'
require 'messages/app_usage_snapshots_create_message'
require 'messages/app_usage_snapshots_list_message'
require 'fetchers/app_usage_snapshot_list_fetcher'
require 'jobs/runtime/app_usage_snapshot_generator_job'

class AppUsageSnapshotsController < ApplicationController
  def index
    message = AppUsageSnapshotsListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    dataset = AppUsageSnapshot.where(guid: [])
    dataset = AppUsageSnapshotListFetcher.fetch_all(message, AppUsageSnapshot.dataset) if permission_queryer.can_read_globally?

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::AppUsageSnapshotPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/app_usage/snapshots',
      message: message
    )
  end

  def show
    snapshot_not_found! unless permission_queryer.can_read_globally?

    snapshot = AppUsageSnapshot.first(guid: hashed_params[:guid])
    snapshot_not_found! unless snapshot

    render status: :ok, json: Presenters::V3::AppUsageSnapshotPresenter.new(snapshot)
  end

  def create
    message = AppUsageSnapshotsCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    unauthorized! unless permission_queryer.can_write_globally?

    existing_snapshot = AppUsageSnapshot.where(completed_at: nil).first
    raise CloudController::Errors::ApiError.new_from_details('AppUsageSnapshotGenerationInProgress') if existing_snapshot

    snapshot = AppUsageSnapshot.create(
      checkpoint_event_guid: nil,
      created_at: Time.now.utc,
      completed_at: nil,
      instance_count: 0,
      organization_count: 0,
      space_count: 0,
      app_count: 0,
      chunk_count: 0
    )

    begin
      job = Jobs::Runtime::AppUsageSnapshotGeneratorJob.new(snapshot.guid)
      pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(job)
    rescue StandardError
      snapshot.destroy
      raise
    end

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  def chunks
    snapshot_not_found! unless permission_queryer.can_read_globally?

    snapshot = AppUsageSnapshot.first(guid: hashed_params[:guid])
    snapshot_not_found! unless snapshot

    unprocessable!('Snapshot is still processing') unless snapshot.complete?

    pagination_options = PaginationOptions.from_params(query_params)
    paginated_result = SequelPaginator.new.get_page(
      snapshot.app_usage_snapshot_chunks_dataset,
      pagination_options
    )

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::AppUsageSnapshotChunkPresenter,
      paginated_result: paginated_result,
      path: "/v3/app_usage/snapshots/#{snapshot.guid}/chunks"
    )
  end

  private

  def snapshot_not_found!
    resource_not_found!(:app_usage_snapshot)
  end
end
