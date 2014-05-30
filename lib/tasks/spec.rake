desc "Runs all specs"
task spec: %w[
              ci:db:recreate
              ci:spec:api
              ci:spec:integration
              ci:spec:services:transactional
              ci:spec:services:non_transactional
              ci:spec:non_services:transactional
              ci:spec:non_services:non_transactional
            ]
