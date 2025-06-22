# Used by "mix format"
export_locals_without_parens = [attr: 1, attr: 2, attr: 3, slot: 1, defstate: 1]

[
  line_length: 120,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: export_locals_without_parens,
  export: [locals_without_parens: export_locals_without_parens]
]
