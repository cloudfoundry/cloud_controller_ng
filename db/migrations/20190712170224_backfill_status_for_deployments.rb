Sequel.migration do
  change do
    transaction do
      run <<-SQL
        UPDATE deployments
          SET status_value='FINALIZED'
          WHERE (status_value IS NULL OR TRIM(status_value) = '')
          AND state in ('DEPLOYED', 'CANCELED', 'FAILED');
        UPDATE deployments
          SET status_value='DEPLOYING'
          WHERE (status_value IS NULL OR TRIM(status_value) = '')
          AND state in ('DEPLOYING','CANCELING','FAILING');
      SQL
    end
  end
end
