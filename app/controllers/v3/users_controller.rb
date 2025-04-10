require 'messages/user_create_message'
require 'messages/users_list_message'
require 'messages/user_update_message'
require 'actions/user_create'
require 'actions/user_delete'
require 'actions/user_update'
require 'presenters/v3/user_presenter'
require 'fetchers/user_list_fetcher'

class UsersController < ApplicationController
  def index
    message = UsersListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?

    users = fetch_readable_users(message)

    paginated_result = SequelPaginator.new.get_page(users, message.try(:pagination_options))
    user_guids = paginated_result.records.map(&:guid)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::UserPresenter,
      paginated_result: paginated_result,
      path: '/v3/users',
      message: message,
      extra_presenter_args: { uaa_users: User.uaa_users_info(user_guids) }
    )
  rescue VCAP::CloudController::UaaUnavailable
    raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
  end

  def show
    user = fetch_user_if_readable(hashed_params[:guid])
    user_not_found! unless user

    render status: :ok, json: Presenters::V3::UserPresenter.new(user, uaa_users: User.uaa_users_info([user.guid]))
  rescue VCAP::CloudController::UaaUnavailable
    raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
  end

  def create
    message = UserCreateMessage.new(hashed_params[:body])
    unauthorized! unless permission_queryer.can_write_globally? || org_managers_can_create_users?
    unprocessable!(message.errors.full_messages) unless message.valid?

    # prevent org_managers from creating users by guid
    unauthorized! if !permission_queryer.can_write_globally? && !(!message.guid && org_managers_can_create_users?)

    user = UserCreate.new.create(message:)

    if message.username && message.origin
      render status: :created,
             json: Presenters::V3::UserPresenter.new(user,
                                                     uaa_users: { user.guid => { 'username' => message.username, 'id' => user.guid, 'origin' => message.origin } })
    else
      render status: :created, json: Presenters::V3::UserPresenter.new(user, uaa_users: User.uaa_users_info([user.guid]))
    end
  rescue UaaRateLimited
    headers['Retry-After'] = rand(5..20).to_s
    raise CloudController::Errors::V3::ApiError.new_from_details('UaaRateLimited')
  rescue VCAP::CloudController::UaaUnavailable
    raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
  rescue UserCreate::Error => e
    unprocessable!(e)
  end

  def update
    user = fetch_user_if_readable(hashed_params[:guid])
    user_not_found! unless user

    unauthorized! unless permission_queryer.can_write_globally?

    message = UserUpdateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    user = UserUpdate.new.update(user:, message:)

    render status: :ok, json: Presenters::V3::UserPresenter.new(user, uaa_users: User.uaa_users_info([hashed_params[:guid]]))
  end

  def destroy
    user = fetch_user_if_readable(hashed_params[:guid])
    user_not_found! unless user

    unauthorized! unless permission_queryer.can_write_globally?

    delete_action = UserDeleteAction.new
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(User, user.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue_pollable(deletion_job)

    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  private

  def fetch_readable_users(message)
    admin_roles = permission_queryer.can_read_globally?
    UserListFetcher.fetch_all(message, current_user.readable_users(admin_roles))
  end

  def fetch_user_if_readable(desired_guid)
    readable_users = current_user.readable_users(permission_queryer.can_read_globally?)
    readable_users.first(guid: desired_guid)
  end

  def user_not_found!
    resource_not_found!(:user)
  end

  def org_managers_can_create_users?
    VCAP::CloudController::Config.config.get(:allow_user_creation_by_org_manager) && permission_queryer.is_org_manager?
  end
end
