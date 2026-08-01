#include "flutter_window.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>
#include <utility>

#include "flutter/generated_plugin_registrant.h"
#include "global_hotkey_hook.h"
#include "non_backup_storage.h"
#include "utils.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  auto storage_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "app.aoki.yuki.vagina/non_backup_storage",
          &flutter::StandardMethodCodec::GetInstance());
  storage_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "hasPackageIdentity") {
          try {
            result->Success(flutter::EncodableValue(HasPackageIdentity()));
          } catch (const std::exception& exception) {
            result->Error("package_identity_unavailable", exception.what());
          }
          return;
        }
        if (call.method_name() == "getNonBackupStorageRoot") {
          try {
            const std::string root =
                Utf8FromUtf16(GetNonBackupStorageRoot().c_str());
            if (root.empty()) {
              result->Error("non_backup_storage_unavailable",
                            "Resolved non-backup storage path is empty.");
              return;
            }
            result->Success(flutter::EncodableValue(root));
          } catch (const std::exception& exception) {
            result->Error("non_backup_storage_unavailable", exception.what());
          }
          return;
        }
        result->NotImplemented();
      });
  non_backup_storage_channel_ = std::move(storage_channel);

  // Set up global hotkey hook.
  global_hotkey_hook_ = std::make_unique<GlobalHotKeyHook>();

  // Set up global hotkey MethodChannel.
  auto hotkey_method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "app.aoki.yuki.vagina/global_hotkey",
          &flutter::StandardMethodCodec::GetInstance());
  hotkey_method_channel->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setBinding") {
          try {
            const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
            if (arguments == nullptr) {
              // Clear binding if no arguments provided.
              global_hotkey_hook_->SetKeyBinding(GlobalHotKeyHook::KeyBinding());
              result->Success();
              return;
            }

            GlobalHotKeyHook::KeyBinding binding;
            if (arguments->find(flutter::EncodableValue("primaryVirtualKeyCode")) !=
                arguments->end()) {
              const auto* key_code =
                  std::get_if<int32_t>(&arguments->at(
                      flutter::EncodableValue("primaryVirtualKeyCode")));
              if (key_code != nullptr) {
                binding.primary_virtual_key_code = *key_code;
              }
            }
            if (arguments->find(flutter::EncodableValue("requiresControl")) !=
                arguments->end()) {
              const auto* requires_ctrl =
                  std::get_if<bool>(&arguments->at(
                      flutter::EncodableValue("requiresControl")));
              if (requires_ctrl != nullptr) {
                binding.requires_control = *requires_ctrl;
              }
            }
            if (arguments->find(flutter::EncodableValue("requiresShift")) !=
                arguments->end()) {
              const auto* requires_shift =
                  std::get_if<bool>(&arguments->at(
                      flutter::EncodableValue("requiresShift")));
              if (requires_shift != nullptr) {
                binding.requires_shift = *requires_shift;
              }
            }
            if (arguments->find(flutter::EncodableValue("requiresAlt")) !=
                arguments->end()) {
              const auto* requires_alt =
                  std::get_if<bool>(&arguments->at(
                      flutter::EncodableValue("requiresAlt")));
              if (requires_alt != nullptr) {
                binding.requires_alt = *requires_alt;
              }
            }
            if (arguments->find(flutter::EncodableValue("requiresMeta")) !=
                arguments->end()) {
              const auto* requires_meta =
                  std::get_if<bool>(&arguments->at(
                      flutter::EncodableValue("requiresMeta")));
              if (requires_meta != nullptr) {
                binding.requires_meta = *requires_meta;
              }
            }

            global_hotkey_hook_->SetKeyBinding(binding);
            result->Success();
          } catch (const std::exception& exception) {
            result->Error("setBinding_error", exception.what());
          }
          return;
        }
        if (call.method_name() == "setActive") {
          try {
            const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
            if (arguments == nullptr) {
              result->Error("setActive_error", "Arguments map is required.");
              return;
            }

            const auto active_entry =
                arguments->find(flutter::EncodableValue("active"));
            if (active_entry == arguments->end()) {
              result->Error("setActive_error", "Missing 'active' boolean argument.");
              return;
            }

            const auto* active_flag = std::get_if<bool>(&active_entry->second);
            if (active_flag == nullptr) {
              result->Error("setActive_error", "Missing 'active' boolean argument.");
              return;
            }

            bool success = false;
            if (*active_flag) {
              success = global_hotkey_hook_->Install(GetHandle());
            } else {
              global_hotkey_hook_->Uninstall();
              success = true;
            }

            result->Success(flutter::EncodableValue(success));
          } catch (const std::exception& exception) {
            result->Error("setActive_error", exception.what());
          }
          return;
        }
        result->NotImplemented();
      });
  global_hotkey_method_channel_ = std::move(hotkey_method_channel);

  // Set up global hotkey EventChannel.
  auto hotkey_event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "app.aoki.yuki.vagina/global_hotkey_events",
          &flutter::StandardMethodCodec::GetInstance());

  auto stream_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<
              flutter::StreamHandlerError<flutter::EncodableValue>> {
        global_hotkey_event_sink_ = std::move(events);
        return nullptr;
      },
      [this](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<
              flutter::StreamHandlerError<flutter::EncodableValue>> {
        global_hotkey_event_sink_.reset();
        return nullptr;
      });

  hotkey_event_channel->SetStreamHandler(std::move(stream_handler));
  global_hotkey_event_channel_ = std::move(hotkey_event_channel);

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  non_backup_storage_channel_.reset();
  global_hotkey_method_channel_.reset();
  global_hotkey_event_channel_.reset();
  global_hotkey_event_sink_.reset();

  // Ensure hook is uninstalled regardless of Dart-side state.
  if (global_hotkey_hook_) {
    global_hotkey_hook_->Uninstall();
    global_hotkey_hook_.reset();
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case kHotKeyEventMessage: {
      if (global_hotkey_event_sink_) {
        const std::string event_type =
            (wparam == kHotKeyEventDown) ? "down" : "up";
        global_hotkey_event_sink_->Success(flutter::EncodableValue(event_type));
      }
      break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
