# Used by "mix format"
export_locals_without_parens = [defattr: 1, defattr: 2, defattr: 3, defslot: 1, defstate: 1]

[
  line_length: 120,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: export_locals_without_parens,
  export: [locals_without_parens: export_locals_without_parens]
]
