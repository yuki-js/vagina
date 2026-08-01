#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "global_hotkey_hook.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      non_backup_storage_channel_;

  // Global hotkey hook for PTT (Push-to-Talk) functionality.
  std::unique_ptr<GlobalHotKeyHook> global_hotkey_hook_;

  // Method channel for global hotkey configuration.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      global_hotkey_method_channel_;

  // Event channel for global hotkey events.
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      global_hotkey_event_channel_;

  // Current event sink for sending hotkey events to Dart.
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
      global_hotkey_event_sink_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
