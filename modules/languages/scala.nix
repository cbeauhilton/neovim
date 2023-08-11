{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
with builtins; let
  cfg = config.vim.languages.scala;

  defaultServer = "metals";
  servers = {
    metals = {
      package = pkgs.metals;
      lspConfig = ''
        -- Scala nvim-metals config
        local metals_config = require("metals").bare_config()
        metals_config.settings = {
          metalsBinaryPath = "${cfg.lsp.package}/bin/metals",
          showImplicitArguments = true,
          showImplicitConversionsAndClasses = true,
           showInferredType = true,
           excludedPackages = {
             "akka.actor.typed.javadsl",
             "com.github.swagger.akka.javadsl"
           }
        }
        metals_config.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
          vim.lsp.diagnostic.on_publish_diagnostics, {
            virtual_text = {
              prefix = '',
            }
          }
        )

        vim.cmd([[augroup lsp]])
        vim.cmd([[autocmd!]])

        scala_on_attach = function(client, bufnr)
          attach_keymaps(client, bufnr)
          local opts = { noremap=true, silent=true, buffer = bufnr }
          vim.keymap.set("n", "<leader>cm", "<Cmd>lua require('metals').commands()<CR>", opts)
          vim.keymap.set("n", "<leader>cs", "<Cmd>lua require('metals').toggle_setting('showImplicitArguments')<CR>", opts)
          vim.keymap.set("n", "<leader>ch", "<Cmd>lua require('metals').worksheet_hover()<CR>", opts)
          vim.keymap.set("n", "<leader>cd", "<Cmd>lua require('metals').open_all_diagnostics()<CR>", opts)
        end

        metals_config.capabilities = capabilities;
        metals_config.on_attach = scala_on_attach;

        local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "scala", "sbt",},
          callback = function()
            require("metals").initialize_or_attach(metals_config)
          end,
          group = nvim_metals_group,
        })
      '';
    };
  };
in {
  options.vim.languages.scala = {
    enable = mkEnableOption "Scala language support";

    treesitter = {
      enable = mkOption {
        description = "Enable Scala treesitter";
        type = types.bool;
        default = config.vim.languages.enableTreesitter;
      };
      package = nvim.types.mkGrammarOption pkgs "scala";
    };

    lsp = {
      enable = mkOption {
        description = "Enable Scala LSP support";
        type = types.bool;
        default = config.vim.languages.enableLSP;
      };
      server = mkOption {
        description = "Scala LSP server to use";
        type = with types; enum (attrNames servers);
        default = defaultServer;
      };
      package = mkOption {
        description = "Scala LSP server package";
        type = types.package;
        default = servers.${cfg.lsp.server}.package;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [cfg.treesitter.package];
    })

    (mkIf cfg.lsp.enable {
      vim.startPlugins = ["nvim-metals"];
      vim.lsp.lspconfig.enable = true;
      vim.lsp.lspconfig.sources.scala-lsp = servers.${cfg.lsp.server}.lspConfig;
    })
  ]);
}
