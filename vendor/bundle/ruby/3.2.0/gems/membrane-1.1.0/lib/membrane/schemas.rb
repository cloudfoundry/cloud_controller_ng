module Membrane
  module Schemas; end
end

Dir[File.dirname(__FILE__) + '/schemas/*.rb'].each { |file| require file }
