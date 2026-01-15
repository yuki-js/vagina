# PWA (Progressive Web App) Implementation

This document describes the PWA implementation for VAGINA (Voice AGI Notepad Agent).

## Overview

The application has been configured as a Progressive Web App to provide a native app-like experience on both desktop and mobile devices.

## Features Implemented

### 1. Manifest Configuration

Location: `web/manifest.json`

- **Display Mode**: `standalone` - Hides browser UI elements (back/forward/reload buttons)
- **App Name**: "VAGINA - Voice AGI Notepad Agent"
- **Short Name**: "VAGINA"
- **Theme Color**: `#0175C2` (Primary blue)
- **Background Color**: `#0175C2`
- **Orientation**: `portrait-primary`

### 2. App Shortcuts

Quick action available from app icon context menu:
- **通話を開始** (Start Call) - Opens app and immediately starts a call

### 3. Icons

Multiple icon sizes provided for different contexts:
- Icon-192.png (192x192) - Standard app icon
- Icon-512.png (512x512) - High-resolution icon
- Icon-maskable-192.png (192x192) - Maskable icon for adaptive icon support
- Icon-maskable-512.png (512x512) - High-resolution maskable icon

### 4. Permissions

- **Clipboard Write**: Enabled via Permissions-Policy header
- **Microphone Access**: Required for voice calls (requested at runtime)

### 5. Service Worker

Location: `web/sw.js`

Basic service worker for caching static resources:
- Caches essential files (index.html, manifest, icons)
- Provides offline fallback for cached resources
- Cache versioning for updates

### 6. Meta Tags

Enhanced HTML meta tags for better PWA support:
- Apple mobile web app capable
- Apple status bar style
- Theme color
- Viewport configuration
- Proper descriptions

## Installation

### Desktop (Chrome/Edge)
1. Visit the web app
2. Click the install icon in the address bar
3. Confirm installation

### Mobile (iOS/Android)
1. Visit the web app
2. Use "Add to Home Screen" from browser menu
3. App will appear on home screen with icon

## Window Behavior

### Desktop
- Opens in smartphone-sized window initially
- Fully resizable - can be used in small or large windows
- Standard OS title bar visible
- No browser navigation buttons (back/forward/reload)

### Mobile
- Full-screen display
- Native app-like experience
- OS status bar visible

## Limitations

As per requirements (Issue #95):
- **No file handling**: App doesn't register for specific file types
- **No multi-window**: Single instance only
- **No offline mode**: Requires internet connection for API calls
- **No background sync**: No background tasks when app is closed
- **No custom title bar**: Uses OS standard title bar

## Testing

### Desktop
1. Navigate to app URL in Chrome/Edge
2. Install as PWA
3. Launch installed app
4. Verify standalone mode (no browser UI)
5. Test "通話を開始" shortcut

### Mobile
1. Add to home screen
2. Launch from home screen icon
3. Verify full-screen mode
4. Test microphone permission flow

## Future Enhancements

Potential improvements not in current scope:
- Offline support with Service Worker caching
- Background sync for pending operations
- Push notifications
- Custom install prompt UI
- Enhanced shortcuts menu
