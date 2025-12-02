# external core dependencies
require "cgi"
require "uri"
require "excon"
require "fileutils"
require "formatador"
require "openssl"
require "time"
require "timeout"
require "ipaddr"

# internal core dependencies
require File.expand_path("core/version", __dir__)

# Mixins
require File.expand_path("core/services_mixin", __dir__)

require File.expand_path("core/attributes", __dir__)
require File.expand_path("core/attributes/default", __dir__)
require File.expand_path("core/attributes/array", __dir__)
require File.expand_path("core/attributes/boolean", __dir__)
require File.expand_path("core/attributes/float", __dir__)
require File.expand_path("core/attributes/integer", __dir__)
require File.expand_path("core/attributes/string", __dir__)
require File.expand_path("core/attributes/time", __dir__)
require File.expand_path("core/attributes/timestamp", __dir__)
require File.expand_path("core/associations/default", __dir__)
require File.expand_path("core/associations/many_identities", __dir__)
require File.expand_path("core/associations/many_models", __dir__)
require File.expand_path("core/associations/one_model", __dir__)
require File.expand_path("core/associations/one_identity", __dir__)
require File.expand_path("core/collection", __dir__)
require File.expand_path("core/association", __dir__)
require File.expand_path("core/connection", __dir__)
require File.expand_path("core/credentials", __dir__)
require File.expand_path("core/current_machine", __dir__)
require File.expand_path("core/deprecation", __dir__)
require File.expand_path("core/errors", __dir__)
require File.expand_path("core/hmac", __dir__)
require File.expand_path("core/logger", __dir__)
require File.expand_path("core/model", __dir__)
require File.expand_path("core/mock", __dir__)
require File.expand_path("core/provider", __dir__)
require File.expand_path("core/service", __dir__)
require File.expand_path("core/ssh", __dir__)
require File.expand_path("core/scp", __dir__)
require File.expand_path("core/time", __dir__)
require File.expand_path("core/utils", __dir__)
require File.expand_path("core/wait_for", __dir__)
require File.expand_path("core/wait_for_defaults", __dir__)
require File.expand_path("core/uuid", __dir__)
require File.expand_path("core/stringify_keys", __dir__)
require File.expand_path("core/whitelist_keys", __dir__)

require File.expand_path("account", __dir__)
require File.expand_path("baremetal", __dir__)
require File.expand_path("billing", __dir__)
require File.expand_path("cdn", __dir__)
require File.expand_path("compute", __dir__)
require File.expand_path("dns", __dir__)
require File.expand_path("identity", __dir__)
require File.expand_path("image", __dir__)
require File.expand_path("introspection", __dir__)
require File.expand_path("metering", __dir__)
require File.expand_path("monitoring", __dir__)
require File.expand_path("nfv", __dir__)
require File.expand_path("network", __dir__)
require File.expand_path("orchestration", __dir__)
require File.expand_path("storage", __dir__)
require File.expand_path("support", __dir__)
require File.expand_path("volume", __dir__)
require File.expand_path("vpn", __dir__)

# Utility
require File.expand_path("formatador", __dir__)
