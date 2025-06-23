local clang_format_ob_arg_str = {
  "{",
  " BasedOnStyle: LLVM,",
  " AccessModifierOffset: -2,",
  " AlignEscapedNewlines: Left,",
  " AlignOperands : true,",
  " AlwaysBreakTemplateDeclarations: true,",
  " BinPackArguments: true,",
  " BinPackParameters: false,",
  " BreakBeforeBinaryOperators: NonAssignment,",
  " Standard: Auto,",
  " IndentWidth: 2,",
  " BreakBeforeBraces: Custom,",
  " BraceWrapping:",
  "    {AfterClass:      true,",
  "    AfterControlStatement: false,",
  "    AfterEnum:       true,",
  "    AfterFunction:   true,",
  "    AfterNamespace:  true,",
  "    AfterObjCDeclaration: false,",
  "    AfterStruct:     true,",
  "    AfterUnion:      true,",
  "    AfterExternBlock: true,",
  "    BeforeCatch:     false,",
  "    BeforeElse:      false,",
  "    IndentBraces:    false,",
  "    SplitEmptyFunction: false,",
  "    SplitEmptyRecord: false,",
  "    SplitEmptyNamespace: false},",
  " ColumnLimit: 100,",
  " AllowAllParametersOfDeclarationOnNextLine: false,",
  " AlignAfterOpenBracket: true",
  "}",
  -- "-assume-filename",
  -- util.escape_path(util.get_current_buffer_file_name()),
}

local clang_format_ob_arg = table.concat(clang_format_ob_arg_str, " ")

local util = require("conform.util")

return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      fish = { "fish_indent" },
      sh = { "shfmt" },
      cpp = { "clang_format_for_ob" },
    },
    log_level = vim.log.levels.ERROR,
    formatters = {
      clang_format_for_ob = {
        -- This can be a string or a function that returns a string.
        -- When defining a new formatter, this is the only field that is required
        command = "clang-format",
        -- A list of strings, or a function that returns a list of strings
        -- Return a single string instead of a list to run the command in a shell
        args = {  "-assume-filename", "$FILENAME", "--style", clang_format_ob_arg, },
        -- If the formatter supports range formatting, create the range arguments here
        range_args = function(self, ctx)
          local start_offset, end_offset = util.get_offsets_from_range(ctx.buf, ctx.range)
          local length = end_offset - start_offset
          return {
            "-assume-filename",
            "$FILENAME",
            "--offset",
            tostring(start_offset),
            "--length",
            tostring(length),
           "--style",
            clang_format_ob_arg,
          }
        end,
      },
    },
  },
}
