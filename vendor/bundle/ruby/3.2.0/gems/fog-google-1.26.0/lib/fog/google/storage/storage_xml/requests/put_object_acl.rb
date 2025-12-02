module Fog
  module Google
    class StorageXML
      class Real
        # TODO: move this methods to helper to use them with put_bucket_acl request
        def tag(name, value)
          "<#{name}>#{value}</#{name}>"
        end

        def scope_tag(scope)
          if %w(AllUsers AllAuthenticatedUsers).include?(scope["type"])
            "<Scope type='#{scope['type']}'/>"
          else
            "<Scope type='#{scope['type']}'>" +
              scope.to_a.reject { |pair| pair[0] == "type" }.map { |pair| tag(pair[0], pair[1]) }.join("\n") +
              "</Scope>"
          end
        end

        def entries_list(access_control_list)
          access_control_list.map do |entry|
            tag("Entry", scope_tag(entry["Scope"]) + tag("Permission", entry["Permission"]))
          end.join("\n")
        end

        def put_object_acl(bucket_name, object_name, acl)
          headers = {}
          data = ""

          if acl.is_a?(Hash)
            data = <<-DATA
<AccessControlList>
  <Owner>
    #{tag('ID', acl['Owner']['ID'])}
  </Owner>
  <Entries>
    #{entries_list(acl['AccessControlList'])}
  </Entries>
</AccessControlList>
DATA
          elsif acl.is_a?(String) && Utils::VALID_ACLS.include?(acl)
            headers["x-goog-acl"] = acl
          else
            raise Excon::Errors::BadRequest.new("invalid x-goog-acl")
          end

          request(:body     => data,
                  :expects  => 200,
                  :headers  => headers,
                  :host     => "#{bucket_name}.#{@host}",
                  :method   => "PUT",
                  :query    => { "acl" => nil },
                  :path     => Fog::Google.escape(object_name))
        end
      end
    end
  end
end
