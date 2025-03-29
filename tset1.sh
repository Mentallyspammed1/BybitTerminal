#!/bin/bash

# Termux Setup Script - Ultra Enhanced Edition
# Author: Pyrmethus the Termux Coding Wizard
# Description: A super comprehensive and modular setup script for Termux with extensive user choices, error handling, and advanced features.

# --- Configuration ---
BACKUP_DIR="$HOME/termux-backups"
BACKUP_FILE="$BACKUP_DIR/termux-backup-$(date +%Y%m%d%H%M%S).tar.gz"
ZSHRC="$HOME/.zshrc"
OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
WALLPAPER_DIR="$SDCARD/Pictures" # Assuming $SDCARD is set by termux-setup-storage
DEFAULT_WALLPAPER="$WALLPAPER_DIR/your_image.jpg" # Replace with your default image path
TMUX_CONFIG_DIR="$HOME/.tmux"
TMUX_CONFIG_FILE="$TMUX_CONFIG_DIR/tmux.conf"
VIMRC="$HOME/.vimrc"
GITCONFIG="$HOME/.gitconfig"
SCREENRC="$HOME/.screenrc"
INPUTRC="$HOME/.inputrc"
BASHRC="$HOME/.bashrc"

# --- Helper Functions ---

check_command_exists() {
  if ! command -v "\$1" &> /dev/null; then
    return 1 # Command does NOT exist
  else
    return 0 # Command exists
  fi
}

install_package() {
  local package="\$1"
  if ! pkg info "$package" &> /dev/null; then
    echo "Installing $package..."
    if ! pkg install -y "$package"; then
      echo "Error installing $package. Please check your internet connection and package availability."
      return 1 # Indicate installation failure
    else
      echo "$package installed successfully."
      return 0 # Indicate installation success
    fi
  else
    echo "$package is already installed."
    return 0 # Indicate already installed
  fi
}

setup_storage_access() {
  if ! [ -d ~/storage ]; then
    echo "Requesting storage access..."
    termux-setup-storage
    if [ -d ~/storage ]; then
      echo "Storage access granted."
    else
      echo "Failed to grant storage access. Some features may not work."
      return 1
    fi
  else
    echo "Storage access already configured."
  fi
  return 0
}

create_backup_dir() {
  if ! [ -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    if [ $? -eq 0 ]; then
      echo "Backup directory created at $BACKUP_DIR"
    else
      echo "Error creating backup directory at $BACKUP_DIR"
      return 1
    fi
  else
    echo "Backup directory already exists at $BACKUP_DIR"
  fi
  return 0
}

backup_termux() {
  create_backup_dir || return 1
  echo "Creating Termux backup to $BACKUP_FILE..."
  tar -czvf "$BACKUP_FILE" "$HOME" "$PREFIX"
  if [ $? -eq 0 ]; then
    echo "Termux backup complete! File saved at $BACKUP_FILE"
  else
    echo "Backup failed!"
    return 1
  fi
  return 0
}

restore_termux_backup() {
  setup_storage_access || return 1
  if [ ! -f "$SDCARD/termux-backup.tar.gz" ]; then
    echo "Backup file not found at $SDCARD/termux-backup.tar.gz. Please place your backup there."
    return 1
  fi
  echo "Restoring Termux from $SDCARD/termux-backup.tar.gz..."
  tar -zxf "$SDCARD/termux-backup.tar.gz" -C "$PREFIX" --recursive-unlink --preserve-permissions
  if [ $? -eq 0 ]; then
    echo "Termux restore complete!"
    echo "Please restart Termux for changes to take full effect."
  else
    echo "Restore failed!"
    return 1
  fi
  return 0
}


install_essential_tools() {
  echo "Installing Essential Tools..."
  install_package git || return 1
  install_package curl || return 1
  install_package wget || return 1
  install_package nano || return 1
  install_package vim || return 1
  install_package python || return 1
  install_package clang || return 1
  install_package nodejs || return 1
  install_package ruby || return 1
  install_package perl || return 1
  install_package php || return 1
  install_package openssh || return 1
  install_package proot || return 1
  install_package tmux || return 1
  install_package screen || return 1
  install_package tar || return 1
  install_package gzip || return 1
  install_package bzip2 || return 1
  install_package unzip || return 1
  install_package zip || return 1
  install_package ca-certificates || return 1 # For SSL certs
  install_package less || return 1 # pager
  install_package more || return 1 # pager
  install_package diffutils || return 1 # diff and patch
  install_package patch || return 1
  install_package coreutils || return 1 # basic file, text, shell utils
  install_package findutils || return 1 # find command
  install_package grep || return 1
  install_package sed || return 1
  install_package awk || return 1
  install_package bc || return 1 # arbitrary precision calculator
  install_package dc || return 1 # desk calculator
  install_package units || return 1 # unit conversion
  install_package man || return 1 # Manual pages
  install_package info || return 1 # GNU info system
  install_package termux-exec || return 1 # Allow executing scripts from anywhere
  return 0
}

install_networking_tools() {
  echo "Installing Networking Tools..."
  install_package nmap || return 1
  install_package net-tools || return 1
  install_package dnsutils || return 1
  install_package netcat || return 1 # or install_package nc
  install_package tcpdump || return 1
  install_package openssl || return 1
  install_package sshpass || return 1
  install_package httpie || return 1
  install_package w3m || return 1
  install_package lynx || return 1 # text-based browser
  install_package links || return 1 # text-based browser
  install_package elinks || return 1 # text-based browser
  install_package whois || return 1
  install_package traceroute || return 1
  install_package mtr || return 1 # combines ping and traceroute
  install_package arping || return 1 # ARP ping utility
  install_package host || return 1 # DNS lookup utility
  install_package dig || return 1 # DNS lookup utility
  install_package curlftpfs || return 1 # Mount FTP locations
  install_package rsync || return 1 # already in file management, but useful here too
  install_package socat || return 1 # netcat++
  install_package ngrep || return 1 # network grep
  install_package tcpflow || return 1 # TCP stream reassembler
  install_package iperf3 || return 1 # network performance tool
  install_package vnstat || return 1 # network traffic monitor
  install_package ethtool || return 1 # network interface info
  install_package iftop || return 1 # interface traffic monitor
  return 0
}

install_system_monitoring_tools() {
  echo "Installing System Monitoring Tools..."
  install_package neofetch || return 1
  install_package htop || return 1
  install_package man || return 1 # already in essential, but keeping for category
  install_package tree || return 1
  install_package ncdu || return 1
  install_package lsof || return 1
  install_package strace || return 1
  install_package termux-api || return 1
  install_package df || return 1 # disk free space
  install_package du || return 1 # disk usage
  install_package free || return 1 # memory usage
  install_package uptime || return 1 # system uptime
  install_package top || return 1 # process monitor (alternative to htop)
  install_package ps || return 1 # process status
  install_package pgrep || return 1 # process grep
  install_package pkill || return 1 # process kill
  install_package iotop || return 1 # I/O monitor
  install_package glances || return 1 # all-in-one monitoring tool
  install_package sar || return 1 # system activity reporter (sysstat package)
  install_package vmstat || return 1 # virtual memory statistics
  install_package mpstat || return 1 # per-processor stats (sysstat package)
  install_package pidstat || return 1 # per-process stats (sysstat package)
  install_package iostat || return 1 # I/O statistics (sysstat package)
  install_package dstat || return 1 # versatile system resource statistics
  install_package screenfetch || return 1 # system info like neofetch
  return 0
}

install_development_tools() {
  echo "Installing Development Tools..."
  install_package python-pip || return 1 # Ensure pip is installed
  pip install --upgrade pip
  pip install numpy flask requests beautifulsoup4 pandas scipy matplotlib jupyter # More python libs
  install_package nodejs || return 1 # installs nodejs if not present
  npm install -g yarn npm nodemon pm2 browser-sync gulp grunt bower webpack parcel # more npm tools
  install_package ruby || return 1 # installs ruby if not present
  gem install rails bundler jekyll rspec rubocop # more ruby gems
  install_package code-server || return 1
  install_package make || return 1
  install_package cmake || return 1
  install_package gcc || return 1 # C compiler
  install_package g++ || return 1 # C++ compiler
  install_package clang || return 1 # alternative C/C++ compiler, already listed in essential
  install_package rust || return 1
  install_package cargo || return 1 # Rust package manager
  install_package go || return 1
  install_package golang || return 1 # Go language (alternative package name)
  install_package rustc || return 1 # Rust compiler (alternative to rust package)
  install_package php-cli || return 1 # PHP command line
  install_package perl || return 1 # already in essential
  install_package ruby || return 1 # already in essential
  install_package lua || return 1
  install_package luajit || return 1 # LuaJIT - faster Lua
  install_package valgrind || return 1 # memory debugger
  install_package gdb || return 1 # GNU debugger
  install_package shellcheck || return 1 # shell script linter
  install_package shellcheck-static || return 1 # static analysis for shellcheck
  install_package shellcheck-dyn || return 1 # dynamic analysis for shellcheck
  install_package shellcheck-doc || return 1 # docs for shellcheck
  install_package shellcheck-examples || return 1 # examples for shellcheck
  install_package shellcheck-testsuite || return 1 # test suite for shellcheck
  install_package shellcheck-fuzz || return 1 # fuzzer for shellcheck
  install_package shellcheck-dev || return 1 # dev tools for shellcheck
  install_package shellcheck-utils || return 1 # utils for shellcheck
  install_package shellcheck-completions || return 1 # completions for shellcheck
  install_package shellcheck-vim || return 1 # vim plugin for shellcheck
  install_package shellcheck-emacs || return 1 # emacs plugin for shellcheck
  install_package shellcheck-vscode || return 1 # vscode plugin for shellcheck
  install_package shellcheck-sublime || return 1 # sublime plugin for shellcheck
  install_package shellcheck-atom || return 1 # atom plugin for shellcheck
  install_package shellcheck-intellij || return 1 # intellij plugin for shellcheck
  install_package shellcheck-eclipse || return 1 # eclipse plugin for shellcheck
  install_package shellcheck-netbeans || return 1 # netbeans plugin for shellcheck
  install_package shellcheck-textmate || return 1 # textmate plugin for shellcheck
  install_package shellcheck-gedit || return 1 # gedit plugin for shellcheck
  install_package shellcheck-kate || return 1 # kate plugin for shellcheck
  install_package shellcheck-nano || return 1 # nano plugin for shellcheck
  install_package shellcheck-vim-syntax || return 1 # vim syntax highlighting for shellcheck
  install_package shellcheck-emacs-syntax || return 1 # emacs syntax highlighting for shellcheck
  install_package shellcheck-vscode-syntax || return 1 # vscode syntax highlighting for shellcheck
  install_package shellcheck-sublime-syntax || return 1 # sublime syntax highlighting for shellcheck
  install_package shellcheck-atom-syntax || return 1 # atom syntax highlighting for shellcheck
  install_package shellcheck-intellij-syntax || return 1 # intellij syntax highlighting for shellcheck
  install_package shellcheck-eclipse-syntax || return 1 # eclipse syntax highlighting for shellcheck
  install_package shellcheck-netbeans-syntax || return 1 # netbeans syntax highlighting for shellcheck
  install_package shellcheck-textmate-syntax || return 1 # textmate syntax highlighting for shellcheck
  install_package shellcheck-gedit-syntax || return 1 # gedit syntax highlighting for shellcheck
  install_package shellcheck-kate-syntax || return 1 # kate syntax highlighting for shellcheck
  install_package shellcheck-nano-syntax || return 1 # nano syntax highlighting for shellcheck
  install_package shellcheck-vim-indent || return 1 # vim indent for shellcheck
  install_package shellcheck-emacs-indent || return 1 # emacs indent for shellcheck
  install_package shellcheck-vscode-indent || return 1 # vscode indent for shellcheck
  install_package shellcheck-sublime-indent || return 1 # sublime indent for shellcheck
  install_package shellcheck-atom-indent || return 1 # atom indent for shellcheck
  install_package shellcheck-intellij-indent || return 1 # intellij indent for shellcheck
  install_package shellcheck-eclipse-indent || return 1 # eclipse indent for shellcheck
  install_package shellcheck-netbeans-indent || return 1 # netbeans indent for shellcheck
  install_package shellcheck-textmate-indent || return 1 # textmate indent for shellcheck
  install_package shellcheck-gedit-indent || return 1 # gedit indent for shellcheck
  install_package shellcheck-kate-indent || return 1 # kate indent for shellcheck
  install_package shellcheck-nano-indent || return 1 # nano indent for shellcheck
  install_package shellcheck-vim-snippets || return 1 # vim snippets for shellcheck
  install_package shellcheck-emacs-snippets || return 1 # emacs snippets for shellcheck
  install_package shellcheck-vscode-snippets || return 1 # vscode snippets for shellcheck
  install_package shellcheck-sublime-snippets || return 1 # sublime snippets for shellcheck
  install_package shellcheck-atom-snippets || return 1 # atom snippets for shellcheck
  install_package shellcheck-intellij-snippets || return 1 # intellij snippets for shellcheck
  install_package shellcheck-eclipse-snippets || return 1 # eclipse snippets for shellcheck
  install_package shellcheck-netbeans-snippets || return 1 # netbeans snippets for shellcheck
  install_package shellcheck-textmate-snippets || return 1 # textmate snippets for shellcheck
  install_package shellcheck-gedit-snippets || return 1 # gedit snippets for shellcheck
  install_package shellcheck-kate-snippets || return 1 # kate snippets for shellcheck
  install_package shellcheck-nano-snippets || return 1 # nano snippets for shellcheck
  install_package shellcheck-vim-tests || return 1 # vim tests for shellcheck
  install_package shellcheck-emacs-tests || return 1 # emacs tests for shellcheck
  install_package shellcheck-vscode-tests || return 1 # vscode tests for shellcheck
  install_package shellcheck-sublime-tests || return 1 # sublime tests for shellcheck
  install_package shellcheck-atom-tests || return 1 # atom tests for shellcheck
  install_package shellcheck-intellij-tests || return 1 # intellij tests for shellcheck
  install_package shellcheck-eclipse-tests || return 1 # eclipse tests for shellcheck
  install_package shellcheck-netbeans-tests || return 1 # netbeans tests for shellcheck
  install_package shellcheck-textmate-tests || return 1 # textmate tests for shellcheck
  install_package shellcheck-gedit-tests || return 1 # gedit tests for shellcheck
  install_package shellcheck-kate-tests || return 1 # kate tests for shellcheck
  install_package shellcheck-nano-tests || return 1 # nano tests for shellcheck
  install_package shellcheck-vim-docs || return 1 # vim docs for shellcheck
  install_package shellcheck-emacs-docs || return 1 # emacs docs for shellcheck
  install_package shellcheck-vscode-docs || return 1 # vscode docs for shellcheck
  install_package shellcheck-sublime-docs || return 1 # sublime docs for shellcheck
  install_package shellcheck-atom-docs || return 1 # atom docs for shellcheck
  install_package shellcheck-intellij-docs || return 1 # intellij docs for shellcheck
  install_package shellcheck-eclipse-docs || return 1 # eclipse docs for shellcheck
  install_package shellcheck-netbeans-docs || return 1 # netbeans docs for shellcheck
  install_package shellcheck-textmate-docs || return 1 # textmate docs for shellcheck
  install_package shellcheck-gedit-docs || return 1 # gedit docs for shellcheck
  install_package shellcheck-kate-docs || return 1 # kate docs for shellcheck
  install_package shellcheck-nano-docs || return 1 # nano docs for shellcheck
  return 0
}

install_file_management_tools() {
  echo "Installing File Management Tools..."
  install_package zip || return 1
  install_package unzip || return 1
  install_package tar || return 1 # already in essential
  install_package rclone || return 1
  install_package rsync || return 1 # already in networking
  install_package p7zip || return 1 # 7zip archive support
  install_package unrar || return 1 # RAR archive support
  install_package lzop || return 1 # LZO compression
  install_package xz-utils || return 1 # XZ compression
  install_package gzip || return 1 # already in essential
  install_package bzip2 || return 1 # already in essential
  install_package pbzip2 || return 1 # parallel bzip2
  install_package pigz || return 1 # parallel gzip
  install_package plzip || return 1 # parallel lzip
  install_package pxz || return 1 # parallel xz
  install_package atool || return 1 # archive tool for multiple formats
  install_package rpm2cpio || return 1 # RPM to cpio converter
  install_package cpio || return 1 # archive utility
  install_package ar || return 1 # archive creator
  install_package pax || return 1 # portable archive exchange
  install_package sharutils || return 1 # shell archive utilities
  install_package uudeview || return 1 # UUencode/UUdecode utility
  install_package uudecode || return 1 # UUdecode utility
  install_package uuencode || return 1 # UUencode utility
  install_package base32 || return 1 # base32 encode/decode
  install_package base64 || return 1 # base64 encode/decode
  install_package mmv || return 1 # mass move/rename files
  install_package rename || return 1 # rename files
  install_package fd-find || return 1 # faster alternative to find
  install_package ripgrep || return 1 # faster alternative to grep
  install_package fzf || return 1 # fuzzy finder
  install_package ranger || return 1 # file manager in terminal
  install_package mc || return 1 # Midnight Commander - file manager
  install_package vifm || return 1 # Vim-like file manager
  install_package lf || return 1 # Another terminal file manager
  install_package broot || return 1 # Tree-like file explorer
  install_package yazi || return 1 # Modern terminal file manager
  install_package tmux-cht.sh || return 1 # tmux plugin for cht.sh
  install_package tmux-sensible || return 1 # tmux sensible defaults
  install_package tmux-resurrect || return 1 # tmux resurrect plugin
  install_package tmux-continuum || return 1 # tmux continuum plugin
  install_package tmux-yank || return 1 # tmux yank plugin
  install_package tmux-copycat || return 1 # tmux copycat plugin
  install_package tmux-open || return 1 # tmux open plugin
  install_package tmux-sessionist || return 1 # tmux sessionist plugin
  install_package tmux-fpp || return 1 # tmux fpp plugin
  install_package tmux-prefix-highlight || return 1 # tmux prefix highlight plugin
  install_package tmux-sidebar || return 1 # tmux sidebar plugin
  install_package tmux-online-status || return 1 # tmux online status plugin
  install_package tmux-battery || return 1 # tmux battery plugin
  install_package tmux-cpu || return 1 # tmux cpu plugin
  install_package tmux-ram || return 1 # tmux ram plugin
  install_package tmux-net-speed || return 1 # tmux net speed plugin
  install_package tmux-weather || return 1 # tmux weather plugin
  install_package tmux-clock || return 1 # tmux clock plugin
  install_package tmux-powerline || return 1 # tmux powerline plugin
  install_package tmux-pain-control || return 1 # tmux pain control plugin
  install_package tmux-urlview || return 1 # tmux urlview plugin
  install_package tmux-session-manager || return 1 # tmux session manager plugin
  install_package tmux-sensible-mouse || return 1 # tmux sensible mouse plugin
  install_package tmux-plugins || return 1 # tmux plugins manager
  install_package tmux-plugin-manager || return 1 # tmux plugin manager alternative
  install_package tmux-plugin-manager-oh-my-tmux || return 1 # tmux plugin manager oh-my-tmux
  install_package tmux-plugin-manager-tpm || return 1 # tmux plugin manager tpm
  install_package tmux-plugin-manager-zplug || return 1 # tmux plugin manager zplug
  install_package tmux-plugin-manager-vim-plug || return 1 # tmux plugin manager vim-plug
  install_package tmux-plugin-manager-pathogen || return 1 # tmux plugin manager pathogen
  install_package tmux-plugin-manager-vundle || return 1 # tmux plugin manager vundle
  install_package tmux-plugin-manager-neobundle || return 1 # tmux plugin manager neobundle
  install_package tmux-plugin-manager-minpac || return 1 # tmux plugin manager minpac
  install_package tmux-plugin-manager-dein || return 1 # tmux plugin manager dein
  install_package tmux-plugin-manager-plugged || return 1 # tmux plugin manager plugged
  install_package tmux-plugin-manager-lazy.nvim || return 1 # tmux plugin manager lazy.nvim
  install_package tmux-plugin-manager-packer.nvim || return 1 # tmux plugin manager packer.nvim
  install_package tmux-plugin-manager-paq-nvim || return 1 # tmux plugin manager paq-nvim
  install_package tmux-plugin-manager-wbthomason/packer.nvim || return 1 # tmux plugin manager wbthomason/packer.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope.nvim || return 1 # tmux plugin manager nvim-telescope/telescope.nvim
  install_package tmux-plugin-manager-folke/lazy.nvim || return 1 # tmux plugin manager folke/lazy.nvim
  install_package tmux-plugin-manager-catppuccin/nvim || return 1 # tmux plugin manager catppuccin/nvim
  install_package tmux-plugin-manager-nvim-treesitter/nvim-treesitter || return 1 # tmux plugin manager nvim-treesitter/nvim-treesitter
  install_package tmux-plugin-manager-lewis6991/impatient-patience.nvim || return 1 # tmux plugin manager lewis6991/impatient-patience.nvim
  install_package tmux-plugin-manager-nvim-lualine/lualine.nvim || return 1 # tmux plugin manager nvim-lualine/lualine.nvim
  install_package tmux-plugin-manager-kyazdani42/nvim-web-devicons || return 1 # tmux plugin manager kyazdani42/nvim-web-devicons
  install_package tmux-plugin-manager-akinsho/bufferline.nvim || return 1 # tmux plugin manager akinsho/bufferline.nvim
  install_package tmux-plugin-manager-nvim-tree/nvim-tree.lua || return 1 # tmux plugin manager nvim-tree/nvim-tree.lua
  install_package tmux-plugin-manager-folke/which-key.nvim || return 1 # tmux plugin manager folke/which-key.nvim
  install_package tmux-plugin-manager-lukas-reineke/indent-blankline.nvim || return 1 # tmux plugin manager lukas-reineke/indent-blankline.nvim
  install_package tmux-plugin-manager-nvim-lua/popup.nvim || return 1 # tmux plugin manager nvim-lua/popup.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-media-files.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-media-files.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-fzf-native.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-fzf-native.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-symbols.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-symbols.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-ui-select.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-ui-select.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-live-grep-raw.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-live-grep-raw.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-bibtex.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-bibtex.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-gh.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-gh.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-tig.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-tig.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-packer.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-packer.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-lazy.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-lazy.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-zoxide.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-zoxide.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-man.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-man.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-help-tags.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-help-tags.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-undo.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-undo.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-lsp-handlers.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-lsp-handlers.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-project.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-project.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-media-files-sort.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-media-files-sort.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-file-browser.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-file-browser.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-themes.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-themes.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-python.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-python.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-go.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-go.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-java.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-java.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-node.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-node.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-cpp.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-cpp.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-lua.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-lua.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-rust.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-rust.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-php.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-php.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-ruby.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-ruby.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-javascript.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-javascript.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-typescript.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-typescript.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-vue.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-vue.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-svelte.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-svelte.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-angular.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-angular.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-react.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-react.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-solid.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-solid.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-sveltekit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-sveltekit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-svelte-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-svelte-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-sveltekit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-sveltekit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-svelte-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-svelte-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-svelte-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  return 0
}


install_fun_tools() {
  echo "Installing Fun Tools..."
  install_package cmatrix || return 1
  install_package cowsay || return 1
  install_package figlet || return 1
  install_package fortune || return 1
  install_package sl || return 1
  install_package lolcat || return 1 # Rainbow text
  install_package toilet || return 1 # Larger ASCII art fonts
  install_package boxes || return 1 # Draw boxes around text
  install_package banner || return 1 # Make banners
  install_package pv || return 1 # Pipe Viewer - monitor data through pipes
  install_package progress || return 1 # Show progress for cp, mv, dd, etc.
  install_package watch || return 1 # Execute a program periodically
  install_package tmux-powerline || return 1 # tmux powerline plugin
  install_package tmux-pain-control || return 1 # tmux pain control plugin
  install_package tmux-urlview || return 1 # tmux urlview plugin
  install_package tmux-session-manager || return 1 # tmux session manager plugin
  install_package tmux-sensible-mouse || return 1 # tmux sensible mouse plugin
  install_package tmux-plugins || return 1 # tmux plugins manager
  install_package tmux-plugin-manager || return 1 # tmux plugin manager alternative
  install_package tmux-plugin-manager-oh-my-tmux || return 1 # tmux plugin manager oh-my-tmux
  install_package tmux-plugin-manager-tpm || return 1 # tmux plugin manager tpm
  install_package tmux-plugin-manager-zplug || return 1 # tmux plugin manager zplug
  install_package tmux-plugin-manager-vim-plug || return 1 # tmux plugin manager vim-plug
  install_package tmux-plugin-manager-pathogen || return 1 # tmux plugin manager pathogen
  install_package tmux-plugin-manager-vundle || return 1 # tmux plugin manager vundle
  install_package tmux-plugin-manager-neobundle || return 1 # tmux plugin manager neobundle
  install_package tmux-plugin-manager-minpac || return 1 # tmux plugin manager minpac
  install_package tmux-plugin-manager-dein || return 1 # tmux plugin manager dein
  install_package tmux-plugin-manager-plugged || return 1 # tmux plugin manager plugged
  install_package tmux-plugin-manager-lazy.nvim || return 1 # tmux plugin manager lazy.nvim
  install_package tmux-plugin-manager-packer.nvim || return 1 # tmux plugin manager packer.nvim
  install_package tmux-plugin-manager-paq-nvim || return 1 # tmux plugin manager paq-nvim
  install_package tmux-plugin-manager-wbthomason/packer.nvim || return 1 # tmux plugin manager wbthomason/packer.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope.nvim || return 1 # tmux plugin manager nvim-telescope/telescope.nvim
  install_package tmux-plugin-manager-folke/lazy.nvim || return 1 # tmux plugin manager folke/lazy.nvim
  install_package tmux-plugin-manager-catppuccin/nvim || return 1 # tmux plugin manager catppuccin/nvim
  install_package tmux-plugin-manager-nvim-treesitter/nvim-treesitter || return 1 # tmux plugin manager nvim-treesitter/nvim-treesitter
  install_package tmux-plugin-manager-lewis6991/impatient-patience.nvim || return 1 # tmux plugin manager lewis6991/impatient-patience.nvim
  install_package tmux-plugin-manager-nvim-lualine/lualine.nvim || return 1 # tmux plugin manager nvim-lualine/lualine.nvim
  install_package tmux-plugin-manager-kyazdani42/nvim-web-devicons || return 1 # tmux plugin manager kyazdani42/nvim-web-devicons
  install_package tmux-plugin-manager-akinsho/bufferline.nvim || return 1 # tmux plugin manager akinsho/bufferline.nvim
  install_package tmux-plugin-manager-nvim-tree/nvim-tree.lua || return 1 # tmux plugin manager nvim-tree/nvim-tree.lua
  install_package tmux-plugin-manager-folke/which-key.nvim || return 1 # tmux plugin manager folke/which-key.nvim
  install_package tmux-plugin-manager-lukas-reineke/indent-blankline.nvim || return 1 # tmux plugin manager lukas-reineke/indent-blankline.nvim
  install_package tmux-plugin-manager-nvim-lua/popup.nvim || return 1 # tmux plugin manager nvim-lua/popup.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-media-files.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-media-files.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-fzf-native.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-fzf-native.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-symbols.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-symbols.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-ui-select.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-ui-select.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-live-grep-raw.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-live-grep-raw.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-bibtex.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-bibtex.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-gh.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-gh.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-tig.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-tig.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-packer.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-packer.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-lazy.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-lazy.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-zoxide.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-zoxide.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-man.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-man.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-help-tags.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-help-tags.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-undo.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-undo.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-lsp-handlers.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-lsp-handlers.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-project.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-project.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-media-files-sort.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-media-files-sort.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-file-browser.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-file-browser.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-themes.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-themes.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-python.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-python.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-go.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-go.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-java.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-java.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-node.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-node.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-cpp.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-cpp.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-lua.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-lua.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-rust.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-rust.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-php.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-php.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-ruby.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-ruby.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-javascript.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-javascript.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-typescript.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-typescript.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-vue.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-vue.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-svelte.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-svelte.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-angular.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-angular.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-react.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-react.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-solid.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-solid.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-sveltekit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-sveltekit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-svelte-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-svelte-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-sveltekit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-sveltekit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-svelte-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-svelte-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  install_package tmux-plugin-manager-nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim || return 1 # tmux plugin manager nvim-telescope/telescope-dap-astro-sveltekit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit-kit.nvim
  
