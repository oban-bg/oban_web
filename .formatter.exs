# Used by "mix format"
[
  import_deps: [
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs,heex}"],
  export: [
    locals_without_parens: [oban_dashboard: 1, oban_dashboard: 2]
  ],
  locals_without_parens: [oban_dashboard: 1, oban_dashboard: 2],
  plugins: [Phoenix.LiveView.HTMLFormatter]
]
