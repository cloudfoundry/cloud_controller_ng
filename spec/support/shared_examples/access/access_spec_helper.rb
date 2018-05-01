RSpec.shared_examples 'an access control' do |operation, table, expected_error=nil|
  describe "#{operation}? and #{operation}_with_token?" do
    table.each do |role, expected_return_value|
      it "returns #{expected_return_value} if user is a(n) #{role}" do
        org_if_defined = respond_to?(:org) ? org : nil
        space_if_defined = respond_to?(:space) ? space : nil

        set_current_user_as_role(role: role, org: org_if_defined, space: space_if_defined, user: user)

        if respond_to?(:queryer)
          allow(queryer).to receive(:can_write_globally?).and_return(role == :admin)
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
