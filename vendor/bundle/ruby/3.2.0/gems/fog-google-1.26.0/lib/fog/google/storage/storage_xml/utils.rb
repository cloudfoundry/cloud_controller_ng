# frozen_string_literal: true

module Fog
  module Google
    class StorageXML
      module Utils
        # https://cloud.google.com/storage/docs/access-control#predefined-acl
        VALID_ACLS = %w(
          authenticated-read
          bucket-owner-full-control
          bucket-owner-read
          private
          project-private
          public-read
          public-read-write
        ).freeze

        def http_url(params, expires)
          "http://#{host_path_query(params, expires)}"
        end

        def https_url(params, expires)
          "https://#{host_path_query(params, expires)}"
        end

        def url(params, expires)
          Fog::Logger.deprecation("Fog::Google::Storage => #url is deprecated, use #https_url instead [light_black](#{caller.first})[/]")
          https_url(params, expires)
        end

        private

        def host_path_query(params, expires)
          params[:headers]["Date"] = expires.to_i
          params[:path] = Fog::Google.escape(params[:path]).gsub("%2F", "/")
          query = []

          if params[:query]
            filtered = params[:query].reject { |k, v| k.nil? || v.nil? }
            query = filtered.map { |k, v| [k.to_s, Fog::Google.escape(v)].join("=") }
          end

          query << "GoogleAccessId=#{@google_storage_access_key_id}"
          query << "Signature=#{CGI.escape(signature(params))}"
          query << "Expires=#{params[:headers]['Date']}"
          "#{params[:host]}/#{params[:path]}?#{query.join('&')}"
        end

        def request_params(params)
          subdomain = params[:host].split(".#{@host}").first
          if @path_style || subdomain !~ /^(?!goog)(?:[a-z]|\d(?!\d{0,2}(?:\.\d{1,3}){3}$))(?:[a-z0-9]|\.(?![.-])|-(?!\.)){1,61}[a-z0-9]$/
            if subdomain =~ /_/
              # https://github.com/fog/fog/pull/1258#issuecomment-10248620.
              Fog::Logger.warning("fog: the specified google storage bucket name (#{subdomain}) is not DNS compliant (only characters a through z, digits 0 through 9, and the hyphen).")
            else
              # - Bucket names must contain only lowercase letters, numbers, dashes (-), underscores (_), and dots (.). Names containing dots require verification.
              # - Bucket names must start and end with a number or letter.
              # - Bucket names must contain 3 to 63 characters. Names containing dots can contain up to 222 characters, but each dot-separated component can be no longer than 63 characters.
              # - Bucket names cannot be represented as an IP address in dotted-decimal notation (for example, 192.168.5.4).
              # - Bucket names cannot begin with the "goog" prefix.
              # - Also, for DNS compliance, you should not have a period adjacent to another period or dash. For example, ".." or "-." or ".-" are not acceptable.
              Fog::Logger.warning("fog: the specified google storage bucket name (#{subdomain}) is not a valid dns name.  See: https://developers.google.com/storage/docs/bucketnaming") unless @path_style
            end

            params[:host] = params[:host].split("#{subdomain}.")[-1]
            if params[:path]
              params[:path] =
                "#{subdomain}/#{params[:path]}"
            else
              params[:path] =
                subdomain.to_s
            end

            subdomain = nil
          end

          params[:subdomain] = subdomain if subdomain && subdomain != @host

          params[:scheme] ||= @scheme
          params[:port] ||= @port
          params
        end
      end
    end
  end
end
