# Architecture Checklist

This checklist helps maintain the feature-based architecture established in the #88 and #94 refactoring.

## When Adding a New Feature

### Planning Phase
- [ ] Feature name chosen (singular, lowercase, e.g., "profile", "analytics")
- [ ] Feature scope defined (what belongs in this feature?)
- [ ] Dependencies identified (what other features/services needed?)
- [ ] Shared code identified (what goes in lib/services or lib/models?)

### Directory Setup
- [ ] Created `lib/features/FEATURE_NAME/`
- [ ] Created `lib/features/FEATURE_NAME/components/` (if UI components needed)
- [ ] Created `lib/features/FEATURE_NAME/providers/` (if state management needed)
- [ ] Created `lib/screens/FEATURE_NAME/` (if full screens needed)

### Implementation
- [ ] Components are in `features/FEATURE_NAME/components/`
- [ ] Providers are in `features/FEATURE_NAME/providers/`
- [ ] Screens are in `lib/screens/FEATURE_NAME/`
- [ ] No circular dependencies between features
- [ ] Shared code extracted to appropriate locations

### Code Quality
- [ ] All files formatted (`dart format .`)
- [ ] No analysis errors (`flutter analyze`)
- [ ] Imports use relative paths correctly
- [ ] Re-exports added to `lib/providers/providers.dart` if needed

### Documentation
- [ ] Feature documented in DEVELOPER_GUIDE.md
- [ ] Import patterns documented
- [ ] Examples provided if complex

## When Refactoring Existing Code

### Preparation
- [ ] Identified code to move
- [ ] Checked for dependencies
- [ ] Planned migration path
- [ ] Created feature directory structure

### Execution
- [ ] Moved files to appropriate locations
- [ ] Updated all imports
- [ ] Added re-exports for backward compatibility
- [ ] Verified no circular dependencies

### Validation
- [ ] `flutter analyze` passes
- [ ] `dart format` applied
- [ ] Tests still pass
- [ ] No breaking changes introduced

### Cleanup
- [ ] Removed old/unused files
- [ ] Updated documentation
- [ ] Committed changes logically

## Code Review Checklist

### Architecture
- [ ] Features are properly separated
- [ ] No business logic in UI components
- [ ] Providers follow Riverpod best practices
- [ ] Shared code is in appropriate locations

### Organization
- [ ] Files in correct directories
- [ ] Naming conventions followed
- [ ] Import paths use correct patterns
- [ ] No TODO/FIXME without issue reference

### Quality
- [ ] Code formatted
- [ ] No analysis warnings/errors
- [ ] Backward compatibility maintained
- [ ] Documentation updated

## Maintenance Tasks

### Monthly
- [ ] Review feature boundaries
- [ ] Check for code duplication across features
- [ ] Identify shared code candidates
- [ ] Update documentation

### Quarterly
- [ ] Evaluate feature organization effectiveness
- [ ] Consider feature consolidation/splitting
- [ ] Review provider organization
- [ ] Update architecture guidelines

## Anti-Patterns to Avoid

### ❌ DON'T
- [ ] Put feature-specific code in `lib/components/`
- [ ] Create giant provider files (>200 lines)
- [ ] Mix multiple features in one directory
- [ ] Create circular feature dependencies
- [ ] Skip backward compatibility
- [ ] Leave orphaned imports
- [ ] Ignore dart format warnings

### ✅ DO
- [ ] Keep features self-contained
- [ ] Use feature-specific imports for new code
- [ ] Maintain re-exports for compatibility
- [ ] Extract shared code to services/models
- [ ] Follow established patterns
- [ ] Document non-obvious decisions
- [ ] Keep providers focused and small

## Quick Reference

### File Locations
```
lib/
├── components/           # Shared UI components
├── features/             # Feature-specific code
│   └── FEATURE/
│       ├── components/  # Feature UI components
│       └── providers/   # Feature state management
├── models/               # Data models (shared)
├── providers/            # Infrastructure providers
├── repositories/         # Data repositories
├── screens/              # Screen-level widgets
└── services/             # Business logic services
```

### Import Patterns
```dart
// Infrastructure
import '../../providers/core_providers.dart';
import '../../providers/repository_providers.dart';

// Features
import '../../features/FEATURE/providers/feature_providers.dart';
import '../../features/FEATURE/components/feature_component.dart';

// Shared
import '../../components/shared_component.dart';
import '../../services/shared_service.dart';
import '../../models/shared_model.dart';
```

### Provider Organization
```dart
// features/FEATURE/providers/feature_providers.dart

// Services
final featureServiceProvider = Provider<FeatureService>((ref) {
  return FeatureService();
});

// State
final featureStateProvider = NotifierProvider<FeatureNotifier, State>(
  FeatureNotifier.new,
);

// Async Data
final featureDataProvider = FutureProvider<Data>((ref) async {
  return await fetchData();
});
```

## Resources

- **REFACTORING.md** - Detailed refactoring overview
- **DEVELOPER_GUIDE.md** - Migration and usage guide
- **Riverpod Docs** - https://riverpod.dev
- **Flutter Best Practices** - https://flutter.dev/docs/development/data-and-backend/state-mgmt

## Questions?

If something doesn't fit the checklist:
1. Check DEVELOPER_GUIDE.md for patterns
2. Look at existing features for examples
3. Discuss with team before creating new patterns
4. Update this checklist with new patterns

---

**Last Updated**: 2026-01-16 (Issues #88 and #94 refactoring)
**Maintainer**: Development Team
