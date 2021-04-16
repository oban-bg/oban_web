# Used by "mix format"
[
  import_deps: [
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    oban_dashboard: 2
  ]
]
