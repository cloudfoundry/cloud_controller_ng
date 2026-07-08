require 'fog/core'

original = Fog::Logger[:deprecation]
Fog::Logger[:deprecation] = nil

require 'fog/aws'

Fog::Logger[:deprecation] = original
