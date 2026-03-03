require "membrane/errors"
require "membrane/schemas/base"

class Membrane::Schemas::Any < Membrane::Schemas::Base
  def validate(object)
    nil
  end
end
