module Fog
  module Google
    class StorageXML
      class Real
        # Get access control list for an Google Storage bucket
        #
        # ==== Parameters
        # * bucket_name<~String> - name of bucket to get access control list for
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~Hash>:
        #     * 'AccessControlPolicy'<~Hash>
        #       * 'Owner'<~Hash>:
        #         * 'DisplayName'<~String> - Display name of object owner
        #         * 'ID'<~String> - Id of object owner
        #       * 'AccessControlList'<~Array>:
        #         * 'Grant'<~Hash>:
        #           * 'Grantee'<~Hash>:
        #              * 'DisplayName'<~String> - Display name of grantee
        #              * 'ID'<~String> - Id of grantee
        #             or
        #              * 'URI'<~String> - URI of group to grant access for
        #           * 'Permission'<~String> - Permission, in [FULL_CONTROL, WRITE, WRITE_ACP, READ, READ_ACP]
        #
        def get_bucket_acl(bucket_name)
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          request(:expects    => 200,
                  :headers    => {},
                  :host       => "#{bucket_name}.#{@host}",
                  :idempotent => true,
                  :method     => "GET",
                  :parser     => Fog::Google::Parsers::Storage::AccessControlList.new,
                  :query      => { "acl" => nil })
        end
      end

      class Mock
        def get_bucket_acl(bucket_name)
          response = Excon::Response.new
          if acl = data[:acls][:bucket][bucket_name]
            response.status = 200
            response.body = acl
          else
            response.status = 404
            raise(Excon::Errors.status_error({ :expects => 200 }, response))
          end
          response
        end
      end
    end
  end
end
