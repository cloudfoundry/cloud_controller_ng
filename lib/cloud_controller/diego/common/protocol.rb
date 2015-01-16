module VCAP::CloudController
  module Diego
    module Common
      class Protocol
        def stop_index_request(app, index)
          ['diego.stop.index', stop_index_message(app, index).to_json]
        end

        def staging_egress_rules
          staging_security_groups = SecurityGroup.where(staging_default: true).all
          EgressNetworkRulesPresenter.new(staging_security_groups).to_array.collect { |sg| transform_rule(sg) }.flatten
        end

        def running_egress_rules(app)
          EgressNetworkRulesPresenter.new(app.space.security_groups).to_array.collect { |sg| transform_rule(sg) }.flatten
        end

        private

        def stop_index_message(app, index)
          {
            'process_guid' => ProcessGuid.from_app(app),
            'index' => index,
          }
        end

        def transform_rule(rule)
          protocol = rule['protocol']
          template = {
            'protocol' => protocol,
            'destination' => rule['destination'],
          }

          case protocol
          when 'icmp'
            template['icmp_info'] = { 'type' => rule['type'], 'code' => rule['code'] }
          when 'tcp', 'udp'
            range = rule['ports'].split('-')
            if range.size == 1
              template['ports'] = range[0].split(',').collect(&:to_i)
            else
              template['port_range'] = { 'start' => range[0].to_i, 'end' => range[1].to_i }
            end
          end

          template['log'] = rule['log'] if rule['log']

          template
        end
      end
    end
  end
end
