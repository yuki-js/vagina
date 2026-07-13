#ifndef RUNNER_NON_BACKUP_STORAGE_H_
#define RUNNER_NON_BACKUP_STORAGE_H_

#include <filesystem>

// Returns true when the process has Windows package identity. Throws
// std::runtime_error when package identity cannot be queried reliably.
bool HasPackageIdentity();

// Returns durable, device-local application storage excluded from packaged-app
// backup and roaming. Throws std::runtime_error when no safe location is
// available.
std::filesystem::path GetNonBackupStorageRoot();

#endif  // RUNNER_NON_BACKUP_STORAGE_H_
