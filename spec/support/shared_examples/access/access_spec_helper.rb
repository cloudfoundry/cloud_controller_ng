RSpec.shared_examples 'an access control' do |operation, table, expected_error=nil|
  describe "#{operation}? and #{operation}_with_token?" do
    table.each do |role, expected_return_value|
      it "returns #{expected_return_value} if user is a(n) #{role}" do
        o = respond_to?(:org) ? org : nil
        s = respond_to?(:space) ? space : nil

        set_current_user_as_role(role: role, org: o, space: s, user: user)

        if respond_to?(:queryer)
          can_read_globally = role == :admin || role == :admin_read_only || role == :global_auditor
          can_write_globally = role == :admin

          can_write_to_org = can_write_globally
          can_write_to_space = can_write_globally

          can_read_from_org = can_read_globally
          can_read_route = can_read_globally

          if o
            can_read_from_org ||= user.organizations.include?(o) || user.managed_organizations.include?(o) ||
              user.audited_organizations.include?(o) || user.billing_managed_organizations.include?(o)

            can_write_to_org ||= user.managed_organizations.include?(o)
            can_read_route = can_read_route || user.managed_organizations.include?(o) ||
              user.audited_organizations.include?(o)
          end

          if s
            can_write_to_space ||= space.has_developer?(user)
            can_read_route ||= space.has_member?(user)
          end

          allow(queryer).to receive(:can_read_globally?).and_return(can_read_globally)
          allow(queryer).to receive(:can_write_globally?).and_return(can_write_globally)

          allow(queryer).to receive(:can_write_to_org?).and_return(can_write_to_org)
          allow(queryer).to receive(:can_write_to_space?).and_return(can_write_to_space)
          allow(queryer).to receive(:can_read_from_org?).and_return(can_read_from_org)

          allow(queryer).to receive(:can_read_route?).and_return(can_read_route)
        end

        saved_error = nil
        actual_with_token = false
        actual_without_token = false
        begin
          actual_with_token = subject.can?("#{operation}_with_token".to_sym, object)

          actual_without_token = if respond_to?(:op_params)
                                   subject.can?(operation, object, op_params)
                                 else
                                   subject.can?(operation, object)
                                 end
        rescue expected_error => e
          saved_error = e
        end

        actual = actual_with_token && actual_without_token && saved_error.blank?

        expect(actual).to eq(expected_return_value),
          "role #{role}: expected #{expected_return_value}, got: #{actual}"
      end
    end
  end
end
