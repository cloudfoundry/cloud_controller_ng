# Copyright (c) 2009-2012 VMware, Inc.
require 'sinatra/base'

module Sinatra
  module Consumes
    # Use as condition on a sinatra route to specify the encoding accepted
    # by that route.
    #
    # @param [Array<Symbol>] types List of mime types to accept for the route.
    def consumes(*types)
      types = Set.new(types)
      types.map! { |t| mime_type(t) }

      condition do
        types.include?(request.content_type)
      end
    end
  end

  register Consumes
end
