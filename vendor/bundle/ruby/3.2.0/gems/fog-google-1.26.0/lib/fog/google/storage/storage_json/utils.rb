# frozen_string_literal: true

require "addressable"

module Fog
  module Google
    class StorageJSON
      module Utils
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
          params[:path] = ::Addressable::URI.encode_component(params[:path], ::Addressable::URI::CharacterClasses::PATH)

          query = []

          if params[:query]
            filtered = params[:query].reject { |k, v| k.nil? || v.nil? }
            query = filtered.map { |k, v| [k.to_s, Fog::Google.escape(v)].join("=") }
          end

          query << "GoogleAccessId=#{google_access_id}"
          query << "Signature=#{CGI.escape(signature(params))}"
          query << "Expires=#{params[:headers]['Date']}"
          "#{params[:host]}/#{params[:path]}?#{query.join('&')}"
        end
      end
    end
  end
end
