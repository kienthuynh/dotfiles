-- clangd: the C/C++ language server. Gives errors as you type, go-to-definition,
-- hover docs, rename, and completion. Neovim has an LSP client built in, so this
-- needs no plugin.
vim.lsp.config('clangd', {
  cmd = {
    'clangd',
    '--background-index',  -- index the whole project, not just open files
    '--clang-tidy',        -- extra lint warnings
    -- Ask the compiler where its headers live. Without this clangd cannot find
    -- <vector> and friends, and reports errors that are not real.
    '--query-driver=/nix/store/*/bin/*clang*,/usr/bin/clang*',
  },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
  -- Searching upward from the open file, the first of these found is the project root.
  root_markers = { 'compile_commands.json', '.clangd', 'CMakeLists.txt', '.git' },
})
vim.lsp.enable('clangd')

-- Turn on completion whenever a language server attaches.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
  end,
})
