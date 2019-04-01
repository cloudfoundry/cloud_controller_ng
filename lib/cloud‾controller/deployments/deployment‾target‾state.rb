module VCAP::CloudController
  class DeploymentTargetState
    attr_reader :rollback_target_revision

    def initialize(app, message)
      @app = app
      @message = message
      @rollback_target_revision = @message.revision_guid && RevisionModel.find(guid: @message.revision_guid)
    end

    def droplet
      @droplet ||= if @message.revision_guid
                     raise DeploymentCreate::Error.new('The revision does not exist') unless rollback_target_revision

                     RevisionDropletSource.new(@rollback_target_revision).get
                   elsif @message.droplet_guid
                     FromGuidDropletSource.new(@message.droplet_guid).get
                   else
                     AppDropletSource.new(@app.droplet).get
                   end
    end

    def environment_variables
      @environment_variables ||= if rollback_target_revision
                                   rollback_target_revision.environment_variables
                                 else
                                   @app.environment_variables
                                 end
    end

    def apply_to_app(app, user_audit_info)
      app.db.transaction do
        app.lock!

        begin
          AppAssignDroplet.new(user_audit_info).assign(app, droplet)
        rescue AppAssignDroplet::Error => e
          raise DeploymentCreate::Error.new(e.message)
        end

        app.update(environment_variables: environment_variables)
        app.save
      end
    end

    class RevisionDropletSource < Struct.new(:revision)
      def get
        droplet = DropletModel.find(guid: revision.droplet_guid)
        unless droplet && droplet.state != DropletModel::EXPIRED_STATE
          raise DeploymentCreate::Error.new('Unable to deploy this revision, the droplet for this revision no longer exists.')
        end

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
end
