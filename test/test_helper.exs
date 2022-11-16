# Increase parallelism, as tests are mostly IO-bound
ExUnit.configure(max_cases: System.schedulers_online() * 4)
ExUnit.start()

:syn.add_node_to_scopes([:syn_excontainers_scope])

{:ok, _agent} = Gestalt.start()
