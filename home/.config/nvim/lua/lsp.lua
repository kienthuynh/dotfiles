-- Language servers, using nvim 0.12's built-in LSP client. No plugin involved.
-- cmd/filetypes/root_markers are spelled out in full because this Neovim ships
-- no bundled server definitions ($VIMRUNTIME/lsp does not exist).
vim.lsp.config('clangd', {
  cmd = {
    'clangd',
    '--background-index',  -- index the whole project, not just open files
    '--clang-tidy',        -- lint diagnostics on top of compiler errors
    -- Let clangd interrogate the compiler that actually built
    -- compile_commands.json to learn where its system headers live. Required
    -- for nixpkgs toolchains, whose compiler is a wrapper script that injects
    -- include paths through the environment rather than the command line, so
    -- those paths never appear in the compile database. Apple's /usr/bin
    -- compiler is listed too, for projects built without a Nix devShell.
    '--query-driver=/nix/store/*/bin/*clang*,/usr/bin/clang*',
  },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
  -- First marker found walking up from the file decides the project root.
  root_markers = { 'compile_commands.json', '.clangd', 'CMakeLists.txt', '.git' },
})
vim.lsp.enable('clangd')

-- Completion is built into 0.12, so there is no completion plugin to maintain.
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end
  end,
})
