#--
# Cloud Foundry
# Copyright (c) [2009-2014] Pivotal Software, Inc. All Rights Reserved.
#
# This product is licensed to you under the Apache License, Version 2.0 (the "License").
# You may not use this product except in compliance with the License.
#
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the
# subcomponent's license, as noted in the LICENSE file.
#++

require 'uaa/http'
require 'addressable/uri'

module CF::UAA

# This class is for apps that need to manage User Accounts, Groups, or OAuth
# Client Registrations. It provides access to the SCIM endpoints on the UAA.
# For more information about SCIM -- the IETF's System for Cross-domain
# Identity Management (formerly known as Simple Cloud Identity Management) --
# see {http://www.simplecloud.info}.
#
# The types of objects and links to their schema are as follows:
# * +:user+ -- {http://www.simplecloud.info/specs/draft-scim-core-schema-01.html#user-resource}
#   or {http://www.simplecloud.info/specs/draft-scim-core-schema-01.html#anchor8}
# * +:group+ -- {http://www.simplecloud.info/specs/draft-scim-core-schema-01.html#group-resource}
#   or {http://www.simplecloud.info/specs/draft-scim-core-schema-01.html#anchor10}
# * +:client+
# * +:user_id+ -- {https://github.com/cloudfoundry/uaa/blob/master/docs/UAA-APIs.rst#converting-userids-to-names}
#
# Naming attributes by type of object:
# * +:user+ is "username"
# * +:group+ is "displayname"
# * +:client+ is "client_id"
class Scim

  include Http

  private

  def force_attr(k)
    kd = k.to_s.downcase
    kc = {
        'username' => 'userName',
        'familyname' => 'familyName',
        'givenname' => 'givenName',
        'middlename' => 'middleName',
        'honorificprefix' => 'honorificPrefix',
        'honorificsuffix' => 'honorificSuffix',
        'displayname' => 'displayName',
        'nickname' => 'nickName',
        'profileurl' => 'profileUrl',
        'streetaddress' => 'streetAddress',
        'postalcode' => 'postalCode',
        'usertype' => 'userType',
        'preferredlanguage' => 'preferredLanguage',
        'x509certificates' => 'x509Certificates',
        'lastmodified' => 'lastModified',
        'externalid' => 'externalId',
        'phonenumbers' => 'phoneNumbers',
        'startindex' => 'startIndex',
        'zoneid' => 'zoneId',
        'includeinactive' => 'includeInactive'
    }[kd]
    kc || kd
  end

  def headers()
    hdrs = { 'authorization' => @auth_header }
    hdrs['X-Identity-Zone-Subdomain'] = @zone if @zone
    hdrs
  end

  # This is very inefficient and should be unnecessary. SCIM (1.1 and early
  # 2.0 drafts) specify that attribute names are case insensitive. However
  # in the UAA attribute names are currently case sensitive. This hack takes
  # a hash with keys as symbols or strings and with any case, and forces
  # the attribute name to the case that the uaa expects.
  def force_case(obj)
    return obj.collect {|o| force_case(o)} if obj.is_a? Array
    return obj unless obj.is_a? Hash
    new_obj = {}
    obj.each {|(k, v)| new_obj[force_attr(k)] = force_case(v) }
    new_obj
  end

  # an attempt to hide some scim and uaa oddities
  def type_info(type, elem)
    scimfo = {
        user: {
            path: '/Users',
            name_attr: 'userName',
            origin_attr: 'origin'
        },
        group: {
            path: '/Groups',
            name_attr: 'displayName',
            origin_attr: 'zoneid'
        },
        client: {
            path: '/oauth/clients',
            name_attr: 'client_id'
        },
        user_id: {
            path: '/ids/Users',
            name_attr: 'userName',
            origin_attr: 'origin',
        },
        group_mapping: {
            path: '/Groups/External',
            name_attr: 'externalGroup',
            origin_attr: 'origin'
        }
    }

    type_info = scimfo[type]

    unless type_info
      raise ArgumentError, "scim resource type must be one of #{scimfo.keys.inspect}"
    end

    value = type_info[elem]

    unless value
      raise ArgumentError, "scim schema element must be one of #{type_info.keys.inspect}"
    end

    value
  end

  def jkey(k) @key_style == :down ? k.to_s : k end

  def fake_client_id(info)
    idk, ck = jkey(:id), jkey(:client_id)
    info[idk] = info[ck] if info[ck] && !info[idk]
  end

  public

  # @param (see Misc.server)
  # @param [String] auth_header a string that can be used in an
  #   authorization header. For OAuth2 with JWT tokens this would be something
  #   like "bearer xxxx.xxxx.xxxx". The {TokenInfo} class provides
  #   {TokenInfo#auth_header} for this purpose.
  # @param [Hash] options can be
  #   * +:symbolize_keys+, if true, returned hash keys are symbols.
  def initialize(target, auth_header, options = {})
    @target, @auth_header = target, auth_header
    @key_style = options[:symbolize_keys] ? :downsym : :down
    @zone = options[:zone]
    initialize_http_options(options)
  end

  # Convenience method to get the naming attribute, e.g. userName for user,
  # displayName for group, client_id for client.
  # @param type (see #add)
  # @return [String] naming attribute
  def name_attr(type) type_info(type, :name_attr) end

  # Creates a SCIM resource.
  # @param [Symbol] type can be :user, :group, :client, :user_id.
  # @param [Hash] info converted to json and sent to the scim endpoint. For schema of
  #   each type of object see {Scim}.
  # @return [Hash] contents of the object, including its +id+ and meta-data.
  def add(type, info)
    path, info = type_info(type, :path), force_case(info)
    reply = json_parse_reply(@key_style, *json_post(@target, path, info,
        headers))
    fake_client_id(reply) if type == :client # hide client reply, not quite scim
    reply
  end

  # Deletes a SCIM resource
  # @param type (see #add)
  # @param [String] id the id attribute of the SCIM object
  # @return [nil]
  def delete(type, id)
    http_delete @target, "#{type_info(type, :path)}/#{Addressable::URI.encode(id)}", @auth_header, @zone
  end

  # Replaces the contents of a SCIM object.
  # @param (see #add)
  # @return (see #add)
  def put(type, info)
    path, info = type_info(type, :path), force_case(info)
    ida = type == :client ? 'client_id' : 'id'
    raise ArgumentError, "info must include #{ida}" unless id = info[ida]
   hdrs = headers
    if info && info['meta'] && (etag = info['meta']['version'])
      hdrs.merge!('if-match' => etag)
    end
    reply = json_parse_reply(@key_style,
        *json_put(@target, "#{path}/#{Addressable::URI.encode(id)}", info, hdrs))

    # hide client endpoints that are not quite scim compatible
    type == :client && !reply ? get(type, info['client_id']): reply
  end

  # Modifies the contents of a SCIM object.
  # @param (see #add)
  # @return (see #add)
  def patch(type, info)
    path, info = type_info(type, :path), force_case(info)
    ida = type == :client ? 'client_id' : 'id'
    raise ArgumentError, "info must include #{ida}" unless id = info[ida]
    hdrs = headers
    if info && info['meta'] && (etag = info['meta']['version'])
      hdrs.merge!('if-match' => etag)
    end
    reply = json_parse_reply(@key_style,
        *json_patch(@target, "#{path}/#{Addressable::URI.encode(id)}", info, hdrs))

    # hide client endpoints that are not quite scim compatible
    type == :client && !reply ? get(type, info['client_id']): reply
  end

  # Gets a set of attributes for each object that matches a given filter.
  # @param (see #add)
  # @param [Hash] query may contain the following keys:
  #   * +attributes+: a comma or space separated list of attribute names to be
  #     returned for each object that matches the filter. If no attribute
  #     list is given, all attributes are returned.
  #   * +filter+: a filter to select which objects are returned. See
  #     {http://www.simplecloud.info/specs/draft-scim-api-01.html#query-resources}
  #   * +startIndex+: for paged output, start index of requested result set.
  #   * +count+: maximum number of results per reply
  # @return [Hash] including a +resources+ array of results and
  #   pagination data.
  def query(type, query = {})
    query = force_case(query).reject {|k, v| v.nil? }
    if attrs = query['attributes']
      attrs = Util.arglist(attrs).map {|a| force_attr(a)}
      query['attributes'] = Util.strlist(attrs, ",")
    end
    qstr = query.empty?? '': "?#{Util.encode_form(query)}"
    info = json_get(@target, "#{type_info(type, :path)}#{qstr}",
        @key_style,  headers)
    unless info.is_a?(Hash) && info[rk = jkey(:resources)].is_a?(Array)

      # hide client endpoints that are not yet scim compatible
      if type == :client && info.is_a?(Hash)
        info = info.each{ |k, v| fake_client_id(v) }.values
        if m = /^client_id\s+eq\s+"([^"]+)"$/i.match(query['filter'])
          idk = jkey(:client_id)
          info = info.select { |c| c[idk].casecmp(m[1]) == 0 }
        end
        return {rk => info}
      end

      raise BadResponse, "invalid reply to #{type} query of #{@target}"
    end
    info
  end

  # Get information about a specific object.
  # @param (see #delete)
  # @return (see #add)
  def get(type, id)
    info = json_get(@target, "#{type_info(type, :path)}/#{Addressable::URI.encode(id)}",
        @key_style, headers)

    fake_client_id(info) if type == :client # hide client reply, not quite scim
    info
  end

  # Get meta information about client
  # @param client_id
  # @return (client meta)
  def get_client_meta(client_id)
    path = type_info(:client, :path)
    json_get(@target, "#{path}/#{Addressable::URI.encode(client_id)}/meta", @key_style, headers)
  end

  # Collects all pages of entries from a query
  # @param type (see #query)
  # @param [Hash] query may contain the following keys:
  #   * +attributes+: a comma or space separated list of attribute names to be
  #     returned for each object that matches the filter. If no attribute
  #     list is given, all attributes are returned.
  #   * +filter+: a filter to select which objects are returned. See
  #     {http://www.simplecloud.info/specs/draft-scim-api-01.html#query-resources}
  # @return [Array] results
  def all_pages(type, query = {})
    query = force_case(query).reject {|k, v| v.nil? }
    query["startindex"], info, rk = 1, [], jkey(:resources)
    while true
      qinfo = query(type, query)
      raise BadResponse unless qinfo[rk]
      return info if qinfo[rk].empty?
      info.concat(qinfo[rk])
      total = qinfo[jkey :totalresults]
      return info unless total && total > info.length
      unless qinfo[jkey :startindex] && qinfo[jkey :itemsperpage]
        raise BadResponse, "incomplete #{type} pagination data from #{@target}"
      end
      query["startindex"] = info.length + 1
    end
  end

  # Gets id/name pairs for given names. For naming attribute of each object type see {Scim}
  # @param type (see #add)
  # @return [Array] array of name/id hashes for each object found
  def ids(type, *names)
    name_attr = type_info(type, :name_attr)
    origin_attr = type_info(type, :origin_attr)

    filter = names.map do |n|
      "#{name_attr} eq \"#{n}\""
    end

    attributes = ['id', name_attr, origin_attr]

    all_pages(type, attributes: attributes.join(','), filter: filter.join(' or '))
  end

  # Convenience method to query for single object by name.
  # @param type (see #add)
  # @param [String] name Value of the Scim object's name attribue. For naming
  #   attribute of each type of object see {Scim}.
  # @return [String] the +id+ attribute of the object
  def id(type, name)
    res = ids(type, name)

    # hide client endpoints that are not scim compatible
    ik, ck = jkey(:id), jkey(:client_id)
    if type == :client && res && res.length > 0 && (res.length > 1 || res[0][ik].nil?)
      cr = res.find { |o| o[ck] && name.casecmp(o[ck]) == 0 }
      return cr[ik] || cr[ck] if cr
    end

    unless res && res.is_a?(Array) && res.length == 1 &&
        res[0].is_a?(Hash) && (id = res[0][jkey :id])
      raise NotFound, "#{name} not found in #{@target}#{type_info(type, :path)}"
    end
    id
  end

  # Change password.
  # * For a user to change their own password, the token in @auth_header must
  #   contain "password.write" scope and the correct +old_password+ must be given.
  # * For an admin to set a user's password, the token in @auth_header must
  #   contain "uaa.admin" scope.
  # @see https://github.com/cloudfoundry/uaa/blob/master/docs/UAA-APIs.rst#change-password-put-useridpassword
  # @see https://github.com/cloudfoundry/uaa/blob/master/docs/UAA-Security.md#password-change
  # @param [String] user_id the {Scim} +id+ attribute of the user
  # @return [Hash] success message from server
  def change_password(user_id, new_password, old_password = nil)
    req = {"password" => new_password}
    req["oldPassword"] = old_password if old_password
    json_parse_reply(@key_style, *json_put(@target,
        "#{type_info(:user, :path)}/#{Addressable::URI.encode(user_id)}/password", req, headers))
  end

  # Change client secret.
  # * For a client to change its own secret, the token in @auth_header must contain
  #   "client.secret" scope and the correct +old_secret+ must be given.
  # * For an admin to set a client secret, the token in @auth_header must contain
  #   "uaa.admin" scope.
  # @see https://github.com/cloudfoundry/uaa/blob/master/docs/UAA-APIs.rst#change-client-secret-put-oauthclientsclient_idsecret
  # @see https://github.com/cloudfoundry/uaa/blob/master/docs/UAA-Security.md#client-secret-mangagement
  # @param [String] client_id the {Scim} +id+ attribute of the client
  # @return [Hash] success message from server
  def change_secret(client_id, new_secret, old_secret = nil)
    req = {"secret" => new_secret }
    req["oldSecret"] = old_secret if old_secret
    json_parse_reply(@key_style, *json_put(@target,
        "#{type_info(:client, :path)}/#{Addressable::URI.encode(client_id)}/secret", req, headers))
  end

  # Change client jwt trust configuration.
  # * For a client to change its jwt client trust, the token in @auth_header must contain
  #   "client.trust" scope.
  # * For an admin to set a client secret, the token in @auth_header must contain
  #   "uaa.admin" scope.
  # @see https://docs.cloudfoundry.org/api/uaa/index.html#change-client-jwt
  # @param [String] client_id the {Scim} +id+ attribute of the client
  # @param [String] jwks_uri the URI to token endpoint
  # @param [String] jwks the JSON Web Key Set
  # @param [String] kid If changeMode is DELETE provide the id of key
  # @param [String] changeMode Change mode, possible is ADD, UPDATE, DELETE
  # @param [String] iss Issuer in case of federation JWT trust
  # @param [String] sub Subject in case of federation JWT trust
  # @param [String] aud Audience in case of federation JWT trust
  # @return [Hash] success message from server
  def change_clientjwt(client_id, jwks_uri = nil, jwks = nil, kid = nil, changeMode = nil, iss = nil, sub = nil, aud = nil)
    req = {"client_id" => client_id }
    req["jwks_uri"] = jwks_uri if jwks_uri
    req["jwks"] = jwks if jwks
    req["kid"] = kid if kid
    req["changeMode"] = changeMode if changeMode
    req["iss"] = iss if iss
    req["sub"] = sub if sub
    req["aud"] = aud if aud
    json_parse_reply(@key_style, *json_put(@target,
                                           "#{type_info(:client, :path)}/#{Addressable::URI.encode(client_id)}/clientjwt", req, headers))
  end

  def unlock_user(user_id)
    req = {"locked" => false}
    json_parse_reply(@key_style, *json_patch(@target,
        "#{type_info(:user, :path)}/#{Addressable::URI.encode(user_id)}/status", req, headers))
  end

  def map_group(group, is_id, external_group, origin = "ldap")
    key_name = is_id ? :groupId : :displayName
    request = {key_name => group, externalGroup: external_group, schemas: ["urn:scim:schemas:core:1.0"], origin: origin }
    result = json_parse_reply(@key_style, *json_post(@target,
                                                     "#{type_info(:group_mapping, :path)}", request,
                                                     headers))
    result
  end

  def unmap_group(group_id, external_group, origin = "ldap")
    http_delete(@target, "#{type_info(:group_mapping, :path)}/groupId/#{group_id}/externalGroup/#{Addressable::URI.encode(external_group)}/origin/#{origin}",
                          @auth_header, @zone)
  end

  def list_group_mappings(start = nil, count = nil)
    json_get(@target, "#{type_info(:group_mapping, :path)}/list?startIndex=#{start}&count=#{count}", @key_style, headers)
  end
end

end
