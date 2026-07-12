#ifndef RUNNER_NON_BACKUP_STORAGE_H_
#define RUNNER_NON_BACKUP_STORAGE_H_

#include <filesystem>

// Returns durable, device-local application storage excluded from packaged-app
// backup and roaming. Throws std::runtime_error when no safe location is
// available.
std::filesystem::path GetNonBackupStorageRoot();

#endif  // RUNNER_NON_BACKUP_STORAGE_H_
