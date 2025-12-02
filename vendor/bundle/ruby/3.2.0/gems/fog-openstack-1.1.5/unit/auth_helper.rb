def auth_response_v3(type, name)
  {
    'token' => {
      'methods'    => ['password'],
      'roles'      => [{
        'id'   => 'id_roles',
        'name' => 'admin'
      }],
      'expires_at' => '2017-11-29T07:45:29.908554Z',
      'project'    => {
        'domain' => {
          'id'   => 'default',
          'name' => 'Default'
        },
        'id'     => 'project_id',
        'name'   => 'admin'
      },
      'catalog'    => [{
        'endpoints' => [
          {
            'region_id' => 'regionOne',
            'url'       => 'http://localhost',
            'region'    => 'regionOne',
            'interface' => 'internal',
            'id'        => 'id_endpoint_internal'
          },
          {
            'region_id' => 'regionOne',
            'url'       => 'http://localhost',
            'region'    => 'regionOne',
            'interface' => 'public',
            'id'        => 'id_endpoint_public'
          },
          {
            'region_id' => 'regionOne',
            'url'       => 'http://localhost',
            'region'    => 'regionOne',
            'interface' => 'admin',
            'id'        => 'id_endpoint_admin'
          }
        ],
        'type'      => type,
        'id'        => 'id_endpoints',
        'name'      => name
      }],
      'user'       => {
        'domain' => {
          'id'   => 'default',
          'name' => 'Default'
        },
        'id'     => 'id_user',
        'name'   => 'admin'
      },
      'audit_ids'  => ['id_audits'],
      'issued_at'  => '2017-11-29T06:45:29.908578Z'
    }
  }
end

def auth_response_v2(type, name)
  {
    'access' => {
      'token'          => {
        'issued_at' => '2017-12-05T10:44:31.454741Z',
        'expires'   => '2017-12-05T11:44:31Z',
        'id'        => '4ae647d3a5294690a3c29bc658e17e26',
        'tenant'    => {
          'description' => 'admin tenant',
          'enabled'     => true,
          'id'          => 'tenant_id',
          'name'        => 'admin'
        },
        'audit_ids' => ['Ye0Rq1HzTk2ggUAg8nDGbQ']
      },
      'serviceCatalog' => [{
        'endpoints'       => [{
          'adminURL'    => 'http://localhost',
          'region'      => 'regionOne',
          'internalURL' => 'http://localhost',
          'id'          => 'id_endpoints',
          'publicURL'   => 'http://localhost'
        }],
        'endpoints_links' => [],
        'type'            => type,
        'name'            => name
      }],
      'user'           => {
        'username'    => 'admin',
        'roles_links' => [],
        'id'          => 'user_id',
        'roles'       => [{
          'name' => 'admin'
        }],
        'name'        => 'admin'
      },
      'metadata'       => {
        'is_admin' => 0,
        'roles'    => ['role_id']
      }
    }
  }
end
