desc "Runs all specs"
task spec: %w[
              ci:db:recreate
              ci:spec:outer
              ci:spec:unit:fast
              ci:spec:unit:lib
              ci:spec:unit:controllers:services
              ci:spec:unit:controllers:runtime
            ]
