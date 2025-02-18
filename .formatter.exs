[
  subdirectories: ["config"],
  inputs: ["{mix,.formatter}.exs", "{lib,test}/**/*.{ex,exs}"],
  line_length: 98,
  locals_without_parens: [step: 4, step: 3],
  plugins: [Styler]
]
