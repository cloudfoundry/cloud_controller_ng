## Route Policies

Route policies control which Cloud Foundry apps, spaces, or organizations can access routes on identity-aware domains. When a domain has `enforce_route_policies` enabled, GoRouter automatically enforces these access controls using mutual TLS (mTLS) to verify the identity of the calling application.

Route policies are defined using a `source` selector that specifies who can access the route:
- `cf:app:<uuid>` - Allow a specific app
- `cf:space:<uuid>` - Allow all apps in a space
- `cf:org:<uuid>` - Allow all apps in an organization
- `cf:any` - Allow any caller (cannot be combined with other sources on the same route)

**Note:** Route policies can only be created for routes on domains where `enforce_route_policies` is `true` and the domain is not internal (internal routes use container-to-container networking and bypass GoRouter).
