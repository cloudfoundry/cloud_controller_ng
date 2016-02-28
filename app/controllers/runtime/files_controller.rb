require 'httpclient'
require 'uri'

module VCAP::CloudController
  class FilesController < RestController::ModelController
    path_base 'apps'
    model_class_name :App

    get "#{path_guid}/instances/:instance_id/files", :files
    get "#{path_guid}/instances/:instance_id/files/*", :files
    def files(guid, search_param, path=nil)
      app = find_guid_and_validate_access(:read, guid)

      info = get_file_uri_for_search_param(app, path, search_param)

      headers = {}
      range = env['HTTP_RANGE']
      if range
        headers['Range'] = range
      end

      uri = info.file_uri_v2
      uri = add_tail(uri) if params.include?('tail')
      [HTTP::FOUND, { 'Location' => uri }, nil]
    end

    private

    # @param [String, URI::Generic] uri
    # @return [String] uri with tail=<whatever> added to query string
    def add_tail(uri)
      uri = URI(uri)
      # query is Array of [key, value1, value2...]
      query = URI.decode_www_form(uri.query || '')
      unless query.assoc('tail')
        query.push(['tail', ''])
      end
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    def get_file_uri_for_search_param(app, path, search_param)
      # Do we really want/need to be accepting a + here?  It is pretty
      # harmless, but it is weird.  Getting rid of it would require checking
      # with the VMC and STS teams to make sure no one expects to be able to
      # send a +.
      match = search_param.match(/^[+]?([0-9]+)$/)
      if match
        instance = match.captures[0].to_i
        Dea::Client.get_file_uri_for_active_instance_by_index(app, path, instance)
      elsif search_param =~ /^[0-9a-zA-z]+$/
        Dea::Client.get_file_uri_by_instance_guid(app, path, search_param)
      else
        msg = "Request failed for app: #{app.name}, path: #{path || '/'}"
        msg << " as the search_param: #{search_param} is invalid."

        raise Errors::ApiError.new_from_details('FileError', msg)
      end
    end
  end
end
