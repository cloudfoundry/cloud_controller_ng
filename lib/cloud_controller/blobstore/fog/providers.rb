require 'fog/core'

# This can be removed once fog-google fixes
# https://github.com/fog/fog-google/issues/421, which will allow us to upgrade
# fog-core to 2.2.4.
original = Fog::Logger[:deprecation]
Fog::Logger[:deprecation] = nil

require 'fog/aliyun'
require 'fog/aws'
require 'fog/local'
require 'fog/google'
require 'fog/azurerm'
require 'fog/openstack'

Fog::Logger[:deprecation] = original
