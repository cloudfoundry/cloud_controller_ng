module CloudController
  module Errors
    module V3
      class ApiError < Errors::ApiError
        def self.new_from_details(name, *args)
          details = V3::Details.new(name)
          new(details, args)
        end
      end
    end
  end
end
