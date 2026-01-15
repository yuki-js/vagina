# Security Policy

## Supported Versions

Currently supported versions for security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of VAGINA seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### Please Do Not

- Open a public GitHub issue for security vulnerabilities
- Discuss the vulnerability in public forums until it has been addressed

### How to Report

1. **Email**: Send details to [maintainer email] (to be added)
2. **Include**: 
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Fix Timeline**: Depending on severity (critical bugs within 7-14 days)
- **Credit**: Security researchers who responsibly disclose vulnerabilities will be credited

## Security Best Practices

### For Users

1. **API Keys**: Never commit Azure OpenAI API keys to version control
2. **Storage**: API keys are stored securely in device-local storage
3. **Updates**: Keep the app updated to receive security patches
4. **Permissions**: Only grant necessary permissions (microphone for calls)

### For Contributors

1. **Dependencies**: Run `flutter pub outdated` regularly
2. **Code Review**: All code changes require review
3. **Testing**: Write security-aware tests
4. **Secrets**: Never hardcode secrets, API keys, or credentials
5. **Input Validation**: Validate all user input
6. **Third-party Libraries**: Keep dependencies up to date

## Known Security Considerations

### Data Storage
- API keys: Stored in platform secure storage
- Session history: Stored locally in JSON files
- No data sent to third parties except Azure OpenAI API

### Network Security
- WebSocket connection to Azure OpenAI uses TLS
- No telemetry or analytics collection
- All audio processing happens client-side

### Platform Permissions
- **Microphone**: Required for voice calls
- **Storage**: Required for saving sessions/settings
- **Internet**: Required for API communication

## Disclosure Policy

When we receive a security bug report, we will:

1. Confirm the problem and determine affected versions
2. Audit code to find similar problems
3. Prepare fixes for all supported releases
4. Release security updates as soon as possible

## Security Updates

Security updates will be released as:
- Patch versions (e.g., 1.0.1) for minor fixes
- Minor versions (e.g., 1.1.0) for larger security enhancements
- Documented in CHANGELOG.md with [SECURITY] tag

## Questions

For general security questions that don't require private disclosure:
- Open a GitHub Discussion
- Tag with `security` label

Thank you for helping keep VAGINA secure!
