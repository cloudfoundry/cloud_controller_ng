module Fog
  module Google
    class DNS
      class Projects < Fog::Collection
        model Fog::Google::DNS::Project

        ##
        # Fetches the representation of an existing Project
        #
        # @param [String] identity Project identity
        # @return [Fog::Google::DNS::Project] Project resource
        def get(identity)
          if project = service.get_project(identity).to_h
            new(project)
          end
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404
          nil
        end
      end
    end
  end
end
