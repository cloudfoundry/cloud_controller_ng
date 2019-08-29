require 'messages/user_create_message'
require 'messages/users_list_message'
require 'actions/user_create'
require 'actions/user_delete'
require 'presenters/v3/user_presenter'
require 'fetchers/user_list_fetcher'

class UsersController < ApplicationController
  def index
    message = UsersListMessage.from_params(query_params)
    unprocessable!(message.errors.full_messages) unless message.valid?
    users = fetch_readable_users(message)
    user_guids = users.map(&:guid)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::UserPresenter,
      paginated_result: SequelPaginator.new.get_page(users, message.try(:pagination_options)),
      path: '/v3/users',
      message: message,
      extra_presenter_args: { uaa_users: uaa_users_info(user_guids) },
    )
  end

  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = UserCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?
    user = UserCreate.new.create(message: message)

    render status: :created, json: Presenters::V3::UserPresenter.new(user, uaa_users: uaa_users_info([user.guid]))
  rescue UserCreate::Error => e
    unprocessable!(e)
  end

  def show
    user = User.find(guid: hashed_params[:guid])

    user_not_found! unless user
    db_user_is_current_user = current_user.guid == user.guid
    user_not_found! unless permission_queryer.can_read_secrets_globally? || db_user_is_current_user

    render status: :ok, json: Presenters::V3::UserPresenter.new(user, uaa_users: uaa_users_info([user.guid]))
  end

  def destroy
    user = User.find(guid: hashed_params[:guid])
    user_not_found! unless user

    db_user_is_current_user = current_user.guid == user.guid
    unauthorized! if db_user_is_current_user && !permission_queryer.can_write_globally?
    user_not_found! unless permission_queryer.can_read_secrets_globally?
    unauthorized! unless permission_queryer.can_write_globally?

    delete_action = UserDeleteAction.new
    deletion_job = VCAP::CloudController::Jobs::DeleteActionJob.new(User, user.guid, delete_action)
    pollable_job = Jobs::Enqueuer.new(deletion_job, queue: 'cc-generic').enqueue_pollable

    url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
    head :accepted, 'Location' => url_builder.build_url(path: "/v3/jobs/#{pollable_job.guid}")
  end

  private

  def fetch_readable_users(message)
    if permission_queryer.can_read_secrets_globally?
      UserListFetcher.fetch_all(message, User.dataset)
    else
      UserListFetcher.fetch_all(message, User.where(guid: current_user.guid))
    end
  end

  def uaa_users_info(user_guids)
    uaa_client = CloudController::DependencyLocator.instance.uaa_client
    uaa_client.users_for_ids(user_guids)
  end

  def user_not_found!
    resource_not_found!(:user)
  end
end
