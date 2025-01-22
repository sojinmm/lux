[
  subdirectories: ["config"],
  inputs: ["{mix,.formatter}.exs", "{lib,test}/**/*.{ex,exs}"],
  line_length: 98,
  plugins: [Styler]
]
