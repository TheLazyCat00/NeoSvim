# NeoSvim 🏊

NeoSvim is a powerful tool that enables you to effortlessly switch between different Neovim configurations. Just like swimming through different pools, NeoSvim lets you dive into and explore various setups without the hassle of manual reconfiguration.

## 🌊 What is NeoSvim?

NeoSvim allows you to:
- Switch between different Neovim configurations seamlessly
- Try out different setups without compromising your existing workflow
- Experiment with new plugins and settings in isolated environments
- Share and collaborate on configurations with others

## 🏄 Installation

To install NeoSvim:

1. Backup your existing Neovim configuration:
   ```bash
   mv ~/.config/nvim ~/.config/nvim.backup   # Linux/macOS
   # or
   move %LOCALAPPDATA%\nvim %LOCALAPPDATA%\nvim.backup   # Windows
   ```

2. Clone the NeoSvim repository:
   ```bash
   git clone https://github.com/yourusername/neosvim.git ~/.config/nvim   # Linux/macOS
   # or
   git clone https://github.com/yourusername/neosvim.git %LOCALAPPDATA%\nvim   # Windows
   ```

3. Launch Neovim and NeoSvim will initialize automatically.

## 🌊 Usage

NeoSvim provides three main commands:

- **Switch** - Switch to a different Neovim configuration:
  ```
  :Switch
  ```
  This will prompt you to enter a Git repository URL containing the configuration you want to switch to.

- **SwitchLogs** - View logs of the most recent configuration switch:
  ```
  :SwitchLogs
  ```
  This opens a floating window displaying detailed information about the last switch operation.

- **Reload** - Reload your current configuration:
  ```
  :Reload
  ```
  This reloads the active configuration without restarting Neovim.

> Note: Sometimes reloading doesnt work. In this case restart Neovim.

## 🔧 How It Works

NeoSvim operates through a clever mechanism that manipulates Neovim's configuration path:

1. It overrides Neovim's `stdpath()` function to redirect the "config" path to a subdirectory
2. When you switch configurations, it clones the target Git repository into this subdirectory
3. NeoSvim then sources the appropriate initialization files from the new configuration

> Note: NeoSvim temporarily changes some Neovim defaults, but they only apply for the current session.
> So if you don't like NeoSvim, just remove it and get back to your config.

This approach allows you to maintain multiple configurations in isolation, with each having its own plugins, settings, and keymaps - all while keeping your original setup intact if you want to revert back.
The name "NeoSvim" represents the fluid nature of swimming (svim) between different Neovim configurations. It offers the freedom to explore and adapt your editor environment to suit different projects or workflows, just like swimming through different waters.

## 🌟 Contributing

Contributions are welcome! Feel free to submit pull requests or open issues to help improve NeoSvim.
