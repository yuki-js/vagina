#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "non_backup_storage.h"
#include "utils.h"

namespace {

// Reads an integer field that Dart may have encoded as either width.
std::optional<int64_t> ReadInt(const flutter::EncodableMap& map,
                               const char* key) {
  const auto entry = map.find(flutter::EncodableValue(key));
  if (entry == map.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<int32_t>(&entry->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&entry->second)) {
    return *value;
  }
  return std::nullopt;
}

std::optional<std::string> ReadString(const flutter::EncodableMap& map,
                                      const char* key) {
  const auto entry = map.find(flutter::EncodableValue(key));
  if (entry == map.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<std::string>(&entry->second)) {
    return *value;
  }
  return std::nullopt;
}

bool ReadBool(const flutter::EncodableMap& map, const char* key) {
  const auto entry = map.find(flutter::EncodableValue(key));
  if (entry == map.end()) {
    return false;
  }
  const auto* value = std::get_if<bool>(&entry->second);
  return value != nullptr && *value;
}

}  // namespace

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

  global_hotkey_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "app.aoki.yuki.vagina/global_hotkeys",
          &flutter::StandardMethodCodec::GetInstance());
  // WM_HOTKEY and the release-tracking timer arrive on this thread, so the
  // callbacks can talk to the channel directly.
  global_hotkey_manager_ = std::make_unique<GlobalHotkeyManager>(
      GetHandle(),
      [this](const std::string& hotkey_id) {
        global_hotkey_channel_->InvokeMethod(
            "onHotkeyPressed",
            std::make_unique<flutter::EncodableValue>(hotkey_id));
      },
      [this](const std::string& hotkey_id) {
        global_hotkey_channel_->InvokeMethod(
            "onHotkeyReleased",
            std::make_unique<flutter::EncodableValue>(hotkey_id));
      });
  global_hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        HandleGlobalHotkeyCall(call, std::move(result));
      });

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

void FlutterWindow::HandleGlobalHotkeyCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!global_hotkey_manager_) {
    result->Error("global_hotkeys_unavailable",
                  "Global hotkeys are not available for this window.");
    return;
  }

  if (call.method_name() == "clearHotkeys") {
    global_hotkey_manager_->Clear();
    result->Success();
    return;
  }

  if (call.method_name() != "setHotkeys") {
    result->NotImplemented();
    return;
  }

  const auto* arguments = std::get_if<flutter::EncodableList>(call.arguments());
  if (arguments == nullptr) {
    result->Error("invalid_arguments",
                  "setHotkeys expects a list of hotkey descriptions.");
    return;
  }

  std::vector<GlobalHotkeyManager::Registration> registrations;
  registrations.reserve(arguments->size());
  for (const flutter::EncodableValue& argument : *arguments) {
    const auto* description = std::get_if<flutter::EncodableMap>(&argument);
    if (description == nullptr) {
      result->Error("invalid_arguments",
                    "Each hotkey description must be a map.");
      return;
    }

    const std::optional<std::string> id = ReadString(*description, "id");
    const std::optional<int64_t> virtual_key_code =
        ReadInt(*description, "virtualKeyCode");
    if (!id.has_value() || id->empty() || !virtual_key_code.has_value()) {
      result->Error("invalid_arguments",
                    "A hotkey description needs an id and a virtualKeyCode.");
      return;
    }

    GlobalHotkeyManager::Registration registration;
    registration.id = *id;
    registration.virtual_key_code = static_cast<UINT>(*virtual_key_code);
    registration.modifiers =
        static_cast<UINT>(ReadInt(*description, "modifiers").value_or(0));
    registration.tracks_release = ReadBool(*description, "tracksRelease");
    registrations.push_back(std::move(registration));
  }

  flutter::EncodableList rejected_ids;
  for (const std::string& rejected_id :
       global_hotkey_manager_->Replace(registrations)) {
    rejected_ids.push_back(flutter::EncodableValue(rejected_id));
  }
  result->Success(flutter::EncodableValue(std::move(rejected_ids)));
}

void FlutterWindow::OnDestroy() {
  global_hotkey_manager_.reset();
  global_hotkey_channel_.reset();
  non_backup_storage_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // System-wide hotkeys are delivered to this window and are not part of the
  // Flutter view's input, so they are claimed before anything else.
  if (global_hotkey_manager_ &&
      global_hotkey_manager_->HandleWindowMessage(message, wparam, lparam)) {
    return 0;
  }

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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
