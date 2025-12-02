module Fog
  module Google
    class DNS
      ##
      # Fetches the representation of an existing Project. Use this method to look up the limits on the number of
      # resources that are associated with your project.
      #
      # @see https://developers.google.com/cloud-dns/api/v1/projects/get
      class Real
        def get_project(identity)
          @dns.get_project(identity)
        end
      end

      class Mock
        def get_project(_identity)
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
