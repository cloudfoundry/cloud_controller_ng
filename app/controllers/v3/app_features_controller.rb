require 'messages/app_feature_update_message'
require 'controllers/v3/mixins/app_sub_resource'
require 'presenters/v3/app_ssh_feature_presenter'
require 'presenters/v3/app_revisions_feature_presenter'
require 'presenters/v3/app_service_binding_k8s_feature_presenter'
require 'presenters/v3/app_file_based_vcap_services_feature_presenter'
require 'presenters/v3/app_ssh_status_presenter'
require 'actions/app_feature_update'
require 'models/helpers/app_features'

class AppFeaturesController < ApplicationController
  include AppSubResource

  TRUSTED_APP_FEATURES = [VCAP::CloudController::AppFeatures::SSH_FEATURE, VCAP::CloudController::AppFeatures::SERVICE_BINDING_K8S_FEATURE,
                          VCAP::CloudController::AppFeatures::FILE_BASED_VCAP_SERVICES_FEATURE].freeze
  UNTRUSTED_APP_FEATURES = [VCAP::CloudController::AppFeatures::REVISIONS_FEATURE].freeze
  APP_FEATURES = (TRUSTED_APP_FEATURES + UNTRUSTED_APP_FEATURES).freeze

  def index
    app, space = AppFetcher.new.fetch(hashed_params[:app_guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    resources = presented_app_features(app)

    render status: :ok, json: {
      resources: resources,
      pagination: present_unpagination_hash(resources, base_url(resource: 'features'))
    }
  end

  def show
    app, space = AppFetcher.new.fetch(hashed_params[:app_guid])
    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)
    resource_not_found!(:feature) unless APP_FEATURES.include?(hashed_params[:name])

    render status: :ok, json: feature_presenter_for(hashed_params[:name], app)
  end

  def update
    app, space = AppFetcher.new.fetch(hashed_params[:app_guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    name = hashed_params[:name]
    resource_not_found!(:feature) unless APP_FEATURES.include?(name)
    if UNTRUSTED_APP_FEATURES.include?(name)
      unauthorized! unless permission_queryer.can_manage_apps_in_active_space?(space.id)
    else
      unauthorized! unless permission_queryer.can_write_to_active_space?(space.id)
    end
    suspended! unless permission_queryer.is_space_active?(space.id)

    message = VCAP::CloudController::AppFeatureUpdateMessage.new(hashed_params['body'])
    unprocessable!(message.errors.full_messages) unless message.valid?

    if message.enabled && both_service_binding_features_enabled?(app, name)
      unprocessable!("'#{VCAP::CloudController::AppFeatures::FILE_BASED_VCAP_SERVICES_FEATURE}' and '#{VCAP::CloudController::AppFeatures::SERVICE_BINDING_K8S_FEATURE}' " \
                     'features cannot be enabled at the same time.')
    end

    AppFeatureUpdate.update(name, app, message)
    render status: :ok, json: feature_presenter_for(name, app)
  end

  def ssh_enabled
    app, space = AppFetcher.new.fetch(hashed_params[:guid])

    app_not_found! unless app && permission_queryer.can_read_from_space?(space.id, space.organization_id)

    render status: :ok, json: Presenters::V3::AppSshStatusPresenter.new(app, Config.config.get(:allow_app_ssh_access))
  end

  private

  def present_unpagination_hash(result, path)
    {
      total_results: result.length,
      total_pages: 1,

      first: { href: path },
      last: { href: path },
      next: nil,
      previous: nil
    }
  end

  def feature_presenter_for(feature_name, app)
    presenters = {
      VCAP::CloudController::AppFeatures::SSH_FEATURE => Presenters::V3::AppSshFeaturePresenter,
      VCAP::CloudController::AppFeatures::REVISIONS_FEATURE => Presenters::V3::AppRevisionsFeaturePresenter,
      VCAP::CloudController::AppFeatures::SERVICE_BINDING_K8S_FEATURE => Presenters::V3::AppServiceBindingK8sFeaturePresenter,
      VCAP::CloudController::AppFeatures::FILE_BASED_VCAP_SERVICES_FEATURE => Presenters::V3::AppFileBasedVcapServicesFeaturePresenter
    }
    presenters[feature_name].new(app)
  end

  def presented_app_features(app)
    [
      Presenters::V3::AppSshFeaturePresenter.new(app),
      Presenters::V3::AppRevisionsFeaturePresenter.new(app),
      Presenters::V3::AppServiceBindingK8sFeaturePresenter.new(app),
      Presenters::V3::AppFileBasedVcapServicesFeaturePresenter.new(app)
    ]
  end

  def both_service_binding_features_enabled?(app, feature_name)
    if feature_name == VCAP::CloudController::AppFeatures::FILE_BASED_VCAP_SERVICES_FEATURE
      app.service_binding_k8s_enabled
    elsif feature_name == VCAP::CloudController::AppFeatures::SERVICE_BINDING_K8S_FEATURE
      app.file_based_vcap_services_enabled
    end
  end
end
