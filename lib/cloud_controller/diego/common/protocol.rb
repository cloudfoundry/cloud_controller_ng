module VCAP::CloudController
  module Diego
    module Common
      class Protocol
        def staging_egress_rules
          staging_security_groups = SecurityGroup.where(staging_default: true).all
          order_rules(EgressNetworkRulesPresenter.new(staging_security_groups).to_array)
        end

        def running_egress_rules(app)
          order_rules(EgressNetworkRulesPresenter.new(app.space.security_groups).to_array)
        end

        private

        def order_rules(rules)
          logging_rules = []
          normal_rules = []

          rules.each do |rule|
            rule = transform_rule(rule)
            rule['log'] ? logging_rules << rule : normal_rules << rule
          end

          normal_rules | logging_rules
        end

        def transform_rule(rule)
          protocol = rule['protocol']
          template = {
            'protocol' => protocol,
            'destinations' => [rule['destination']],
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
