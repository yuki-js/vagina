#include "non_backup_storage.h"

#include <appmodel.h>
#include <shlobj.h>
#include <windows.h>

#include <cstdlib>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

std::filesystem::path GetLocalAppDataPath() {
  PWSTR raw_path = nullptr;
  const HRESULT result = SHGetKnownFolderPath(
      FOLDERID_LocalAppData, KF_FLAG_DEFAULT, nullptr, &raw_path);
  if (FAILED(result) || raw_path == nullptr) {
    throw std::runtime_error("Could not resolve Local AppData.");
  }

  const std::filesystem::path path(raw_path);
  CoTaskMemFree(raw_path);
  return path;
}

std::wstring GetCurrentPackageFamilyNameIfPackaged() {
  UINT32 length = 0;
  LONG result = GetCurrentPackageFamilyName(&length, nullptr);
  if (result == APPMODEL_ERROR_NO_PACKAGE) {
    return {};
  }
  if (result != ERROR_INSUFFICIENT_BUFFER || length == 0) {
    throw std::runtime_error("Could not query the current package family.");
  }

  std::vector<wchar_t> buffer(length);
  result = GetCurrentPackageFamilyName(&length, buffer.data());
  if (result != ERROR_SUCCESS) {
    throw std::runtime_error("Could not read the current package family.");
  }
  return std::wstring(buffer.data());
}

}  // namespace

bool HasPackageIdentity() {
  return !GetCurrentPackageFamilyNameIfPackaged().empty();
}

std::filesystem::path GetNonBackupStorageRoot() {
  const std::filesystem::path local_app_data = GetLocalAppDataPath();
  const std::wstring package_family = GetCurrentPackageFamilyNameIfPackaged();
  const std::filesystem::path root = package_family.empty()
                                         ? local_app_data / L"AokiApp"
                                         : local_app_data / L"Packages" /
                                               package_family / L"LocalCache";

  std::error_code error;
  std::filesystem::create_directories(root, error);
  if (error) {
    throw std::runtime_error("Could not create non-backup app storage.");
  }
  return root;
}
