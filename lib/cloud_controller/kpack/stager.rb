require 'kubernetes/update_reapply_client'

module Kpack
  class Stager
    CF_DEFAULT_BUILDER_REFERENCE = {
      name: 'cf-default-builder',
      kind: 'Builder'
    }.freeze
    APP_GUID_LABEL_KEY = 'cloudfoundry.org/app_guid'.freeze
    BUILD_GUID_LABEL_KEY = 'cloudfoundry.org/build_guid'.freeze
    DROPLET_GUID_LABEL_KEY = 'cloudfoundry.org/droplet_guid'.freeze
    STAGING_SOURCE_LABEL_KEY = 'cloudfoundry.org/source_type'.freeze

    def initialize(builder_namespace:, registry_service_account_name:, registry_tag_base:)
      @builder_namespace = builder_namespace
      @registry_service_account_name = registry_service_account_name
      @registry_tag_base = registry_tag_base
    end

    def stage(staging_details)
      builder_reference = find_or_create_builder_reference(staging_details)
      image_resource_name = staging_details.package.app.guid

      unless client.get_image(image_resource_name, builder_namespace).present?
        return client.create_image(image_resource(staging_details, builder_reference))
      end

      reapply_client.apply_image_update(image_resource_name, builder_namespace) do |existing_image|
        update_image_resource(existing_image, staging_details, builder_reference)
      end
    rescue CloudController::Errors::ApiError => e
      build = VCAP::CloudController::BuildModel.find(guid: staging_details.staging_guid)
      mark_build_as_failed(build, e.message) if build
      logger.error('stage.package', package_guid: staging_details.package.guid, staging_guid: staging_details.staging_guid, error: e)
      raise e
    end

    def stop_stage
      raise NoMethodError
    end

    def staging_complete
      raise NoMethodError
    end

    private

    attr_reader :builder_namespace, :registry_service_account_name, :registry_tag_base

    def mark_build_as_failed(build, message)
      build.class.db.transaction do
        build.lock!
        build.fail_to_stage!('StagingError', "Failed to create Image resource for Kpack: '#{message}'")
      end
    end

    def update_image_resource(image, staging_details, builder_spec)
      image.metadata.labels[DROPLET_GUID_LABEL_KEY.to_sym] = create_droplet_and_get_guid(staging_details)
      image.metadata.labels[BUILD_GUID_LABEL_KEY.to_sym] = staging_details.staging_guid
      image.spec.source = configure_source(staging_details)
      image.spec.build.env = get_environment_variables(staging_details)
      image.spec.builder = builder_spec

      image
    end

    def image_resource(staging_details, builder_spec)
      Kubeclient::Resource.new({
        metadata: {
          name: staging_details.package.app.guid,
          namespace: builder_namespace,
          labels: {
            APP_GUID_LABEL_KEY.to_sym => staging_details.package.app.guid,
            BUILD_GUID_LABEL_KEY.to_sym => staging_details.staging_guid,
            DROPLET_GUID_LABEL_KEY.to_sym => create_droplet_and_get_guid(staging_details),
            STAGING_SOURCE_LABEL_KEY.to_sym => 'STG'
          },
          annotations: {
            'sidecar.istio.io/inject' => 'false'
          },
        },
        spec: {
          serviceAccount: registry_service_account_name,
          builder: builder_spec,
          tag: "#{registry_tag_base}/#{staging_details.package.app.guid}",
          source: configure_source(staging_details),
          build: {
            env: get_environment_variables(staging_details),
          }
        }
      })
    end

    def configure_source(staging_details)
      {
        registry: {
          image: staging_details.package.bits_image_reference(digest: true),
        }
      }
    end

    def get_environment_variables(staging_details)
      staging_details.environment_variables.
        except('VCAP_SERVICES').
        map { |key, value| { name: key, value: value.to_s } }
    end

    def find_or_create_builder_reference(staging_details)
      return CF_DEFAULT_BUILDER_REFERENCE unless staging_details.lifecycle.buildpack_infos.present?

      builder_name = "app-#{staging_details.package.app.guid}"
      create_or_update_builder(builder_name, staging_details)

      {
        name: builder_name,
        kind: 'Builder'
      }
    end

    def create_or_update_builder(name, staging_details)
      desired_builder = generate_builder_from_default(name, staging_details)

      unless client.get_builder(name, builder_namespace).present?
        return client.create_builder(desired_builder)
      end

      reapply_client.apply_builder_update(name, builder_namespace) do |existing_builder|
        desired_builder.metadata.resourceVersion = existing_builder.metadata.resourceVersion
        desired_builder.apiVersion = existing_builder.apiVersion
        desired_builder
      end
    end

    def generate_builder_from_default(name, staging_details)
      default_builder = client.get_builder(CF_DEFAULT_BUILDER_REFERENCE[:name], builder_namespace)
      Kubeclient::Resource.new({
        kind: 'Builder',
        metadata: {
          name: name,
          namespace: builder_namespace,
          labels: {
            APP_GUID_LABEL_KEY.to_sym => staging_details.package.app.guid,
            BUILD_GUID_LABEL_KEY.to_sym => staging_details.staging_guid,
            STAGING_SOURCE_LABEL_KEY.to_sym => 'STG'
          },
        },
        spec: {
          serviceAccount: default_builder.spec.serviceAccount,
          stack: default_builder.spec.stack,
          store: default_builder.spec.store,
          tag: "#{registry_tag_base}/#{staging_details.package.app.guid}-builder",
          order: [
            { group: staging_details.lifecycle.buildpack_infos.map { |buildpack| { id: buildpack } } }
          ]
        }
      })
    end

    def logger
      @logger ||= Steno.logger('cc.stager')
    end

    def client
      ::CloudController::DependencyLocator.instance.k8s_api_client
    end

    def config
      VCAP::CloudController::Config.config
    end

    def reapply_client
      @reapply_client ||= Kubernetes::UpdateReapplyClient.new(client)
    end

    def blobstore_url_generator
      ::CloudController::DependencyLocator.instance.blobstore_url_generator
    end

    def create_droplet_and_get_guid(staging_details)
      build = VCAP::CloudController::BuildModel.find(guid: staging_details.staging_guid)
      droplet = VCAP::CloudController::DropletCreate.new.create_kpack_droplet(build)
      droplet.guid
    end
  end
end
