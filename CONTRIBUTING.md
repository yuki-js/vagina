# Contributing to VAGINA

Thank you for your interest in contributing to VAGINA (Voice AGI Notepad Agent)!

## Code of Conduct

Please be respectful and constructive in all interactions.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yuki-js/vagina/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - Platform/OS information
   - Screenshots if applicable

### Suggesting Features

1. Check [Issues](https://github.com/yuki-js/vagina/issues) for similar suggestions
2. Create a new issue with the `enhancement` label
3. Describe the feature and its benefits
4. Include use cases and examples

### Pull Requests

1. **Fork the repository**

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the coding standards (see below)
   - Add tests for new functionality
   - Update documentation as needed

4. **Test your changes**
   ```bash
   flutter analyze --no-fatal-infos
   flutter test
   ```

5. **Commit your changes**
   ```bash
   git commit -m "Add: brief description of changes"
   ```
   
   Commit message conventions:
   - `Add:` for new features
   - `Fix:` for bug fixes
   - `Update:` for changes to existing features
   - `Refactor:` for code refactoring
   - `Docs:` for documentation changes
   - `Test:` for test-related changes

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Provide a clear description of changes
   - Reference any related issues
   - Ensure CI checks pass

## Coding Standards

### Dart/Flutter

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `dart format` to format code
- Run `flutter analyze` before committing
- Add comments for complex logic (in English or Japanese)
- Use meaningful variable and function names

### Architecture

- Follow existing project structure
- Services for business logic
- Repositories for data persistence
- Providers for state management
- Models for data classes
- UI components should be focused and reusable

### Testing

- Add unit tests for new services and utilities
- Add widget tests for new UI components
- Ensure all tests pass before submitting PR
- Aim for meaningful test coverage

### Documentation

- Update README.md if adding new features
- Add/update documentation in `docs/` for significant changes
- Include inline documentation for public APIs
- Update CHANGELOG.md

## Development Setup

### Prerequisites

- Flutter SDK 3.27.1 (managed via fvm)
- Azure OpenAI API access with Realtime API

### Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/vagina.git
cd vagina

# Install Flutter version via fvm
fvm install

# Get dependencies
fvm flutter pub get

# Run the app
fvm flutter run
```

### Development Workflow

1. Make changes in feature branch
2. Run `flutter analyze`
3. Run `flutter test`  
4. Test manually on at least one platform
5. Commit with descriptive message
6. Push and create PR

## Project Structure

```
lib/
├── models/         # Data models
├── services/       # Business logic
├── providers/      # State management (Riverpod)
├── repositories/   # Data persistence
├── screens/        # UI screens
├── components/     # Reusable widgets
├── theme/          # Theme and styling
└── utils/          # Utility functions

test/
├── models/         # Model tests
├── services/       # Service tests
└── repositories/   # Repository tests
```

## Platform-Specific Guidelines

### Windows
- Use `taudio` for audio playback
- Test audio functionality thoroughly
- See `docs/WINDOWS_BUILD.md`

### Web
- Test PWA functionality
- Verify service worker behavior
- Check responsive design

### Android/iOS
- Test microphone permissions
- Verify audio recording/playback
- Check for platform-specific UI issues

## CI/CD

All PRs must pass:
- `flutter analyze --no-fatal-infos` (0 errors)
- `flutter test` (all tests passing)
- Agent compliance validation script

## Getting Help

- Create an issue for questions
- Check existing documentation in `docs/`
- Review similar PRs for examples

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Recognition

Contributors will be acknowledged in release notes and CHANGELOG.md.

Thank you for contributing to VAGINA! 🎉
