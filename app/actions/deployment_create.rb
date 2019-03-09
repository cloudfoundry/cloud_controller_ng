require 'repositories/deployment_event_repository'

module VCAP::CloudController
  class DeploymentCreate
    class Error < StandardError; end

    class << self
      def create(app:, user_audit_info:, message:)
        previous_droplet = app.droplet

        target_state = DeploymentTargetState.new(app, message)
        target_state.apply_to_app(app, user_audit_info)

        web_process = app.oldest_web_process
        previous_deployment = DeploymentModel.find(app: app, state: DeploymentModel::DEPLOYING_STATE)

        desired_instances = web_process.instances
        if previous_deployment
          desired_instances = previous_deployment.original_web_process_instance_count
        end

        deployment = DeploymentModel.new(
          app: app,
          state: DeploymentModel::DEPLOYING_STATE,
          droplet: target_state.droplet,
          previous_droplet: previous_droplet,
          original_web_process_instance_count: desired_instances,
        )

        DeploymentModel.db.transaction do
          if previous_deployment
            previous_deployment.update(state: DeploymentModel::DEPLOYED_STATE)
            previous_deployment.save
          end

          deployment.save

          MetadataUpdate.update(deployment, message)

          process = create_deployment_process(app, deployment.guid, web_process)
          target_state.apply_to_process(process)

          revision = if app.can_create_revision?(target_state.version)
                       RevisionCreate.create(app, user_audit_info, previous_version: target_state.version)
                     else
                       web_process&.revision
                     end
          deployment.update(revision_guid: revision&.guid, revision_version: revision&.version)
          process.update(revision: revision)
          # Need to transition from STOPPED to STARTED to engage the ProcessObserver to desire the LRP.
          # It'd be better to do this via Diego::Runner.new(process, config).start,
          # but it is nontrivial to get that working in test.
          process.reload.update(state: ProcessModel::STARTED)

          deployment.update(deploying_web_process: process)
        end
        record_audit_event(deployment, target_state.droplet, user_audit_info, message)

        deployment
      end

      def create_deployment_process(app, deployment_guid, web_process)
        process = clone_existing_web_process(app, web_process)

        DeploymentProcessModel.create(
          deployment_guid: deployment_guid,
          process_guid: process.guid,
          process_type: process.type
        )

        process
      end

      def clone_existing_web_process(app, web_process)
        ProcessModel.create(
          app: app,
          type: ProcessTypes::WEB,
          state: ProcessModel::STOPPED,
          instances: 1,
          command: web_process.command,
          memory: web_process.memory,
          file_descriptors: web_process.file_descriptors,
          disk_quota: web_process.disk_quota,
          metadata: web_process.metadata,
          detected_buildpack: web_process.detected_buildpack,
          health_check_timeout: web_process.health_check_timeout,
          health_check_type: web_process.health_check_type,
          health_check_http_endpoint: web_process.health_check_http_endpoint,
          health_check_invocation_timeout: web_process.health_check_invocation_timeout,
          enable_ssh: web_process.enable_ssh,
          ports: web_process.ports,
        )
      end

      def record_audit_event(deployment, droplet, user_audit_info, message)
        app = deployment.app
        type = message.revision_guid ? 'rollback' : nil
        Repositories::DeploymentEventRepository.record_create(
          deployment,
            droplet,
            user_audit_info,
            app.name,
            app.space_guid,
            app.space.organization_guid,
            message.audit_hash,
            type
        )
      end
    end
  end

  class DeploymentTargetState
    attr_reader :droplet, :environment_variables, :version, :rollback_target_revision

    def initialize(app, message)
      @rollback_target_revision = nil

      @droplet = if message.revision_guid
                   @rollback_target_revision = RevisionModel.find(guid: message.revision_guid)
                   raise DeploymentCreate::Error.new('The revision does not exist') unless rollback_target_revision

                   @version = @rollback_target_revision.version
                   RevisionDropletSource.new(@rollback_target_revision).get
                 elsif message.droplet_guid
                   FromGuidDropletSource.new(message.droplet_guid).get
                 else
                   AppDropletSource.new(app.droplet).get
                 end

      @environment_variables = if @rollback_target_revision
                                 @rollback_target_revision.environment_variables
                               else
                                 app.environment_variables
                               end

      @commands_by_process_type = if @rollback_target_revision
                                    @rollback_target_revision.commands_by_process_type
                                  else
                                    app.commands_by_process_type
                                  end
    end

    def apply_to_app(app, user_audit_info)
      app.db.transaction do
        app.lock!

        begin
          AppAssignDroplet.new(user_audit_info).assign(app, @droplet)
        rescue AppAssignDroplet::Error => e
          raise DeploymentCreate::Error.new(e.message)
        end

        app.update(environment_variables: @environment_variables)
        app.save
      end
    end

    def apply_to_process(process)
      process.db.transaction do
        process.lock!
        process.update(command: @commands_by_process_type[process.type])
      end
    end
  end

  class RevisionDropletSource < Struct.new(:revision)
    def get
      droplet = DropletModel.find(guid: revision.droplet_guid)
      raise DeploymentCreate::Error.new('Unable to deploy this revision, the droplet for this revision no longer exists.') unless
          droplet && droplet.state != DropletModel::EXPIRED_STATE

      droplet
    end
  end

  class AppDropletSource < Struct.new(:droplet)
    def get
      raise DeploymentCreate::Error.new('Invalid droplet. Please specify a droplet in the request or set a current droplet for the app.') unless droplet

      droplet
    end
  end

  class FromGuidDropletSource < Struct.new(:droplet_guid)
    def get
      DropletModel.find(guid: droplet_guid)
    end
  end
end
