# port of legacy acount capacity model
module VCAP::CloudController
  class AccountCapacity
    DEFAULT_MEM      = 2 * 1024 # 8GB total
    DEFAULT_URIS     = 4      # per app
    DEFAULT_SERVICES = 16     # total
    DEFAULT_APPS     = 20     # total

    ADMIN_MEM        = 32 * 1024 # 32GB total
    ADMIN_URIS       = 16      # per app
    ADMIN_SERVICES   = 32      # total
    ADMIN_APPS       = 200     # total

    class << self
      def default
        @default ||= {
          memory: DEFAULT_MEM,
          app_uris: DEFAULT_URIS,
          services: DEFAULT_SERVICES,
          apps: DEFAULT_APPS
        }
      end

      def admin
        @admin ||= {
          memory: ADMIN_MEM,
          app_uris: ADMIN_URIS,
          services: ADMIN_SERVICES,
          apps: ADMIN_APPS
        }
      end
    end
  end
end
