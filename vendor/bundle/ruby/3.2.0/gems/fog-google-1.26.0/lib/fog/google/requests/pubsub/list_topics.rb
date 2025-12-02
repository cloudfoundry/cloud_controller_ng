module Fog
  module Google
    class Pubsub
      class Real
        # Gets a list of all topics for a given project.
        #
        # @param_name project [#to_s] Project path to list topics under; must
        #   be a project url prefix (e.g. 'projects/my-project'). If nil, the
        #   project configured on the client is used.
        # @see https://cloud.google.com/pubsub/reference/rest/v1/projects.topics/list
        def list_topics(project = nil)
          if project.nil?
            project = "projects/#{@project}"
          else
            project = project.to_s
          end

          @pubsub.list_topics(project)
        end
      end

      class Mock
        def list_topics(_project = nil)
          raise Fog::Errors::MockNotImplemented
        end
      end
    end
  end
end
