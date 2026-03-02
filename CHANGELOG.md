# Changelog

All notable changes to the VAGINA project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-18

### Added

#### Text Agent System
- **Text Agent Support**: New specialized AI assistants for deep analysis and long-form content
  - Create and manage multiple text agents with Azure OpenAI configuration
  - Configure endpoint, API key, deployment, temperature, and token limits per agent
  - Support for custom system prompts and specialization tags
  - Agent CRUD operations with persistent storage

#### Latency
- Text agent queries are synchronous with a fixed 30-second timeout.

#### New Voice Agent Tools
- **end_call Tool**: Programmatic call termination
  - Voice agents can end calls automatically
  - Optional context parameter for state preservation
  - Graceful call ending with session save
  
- **query_text_agent Tool**: Query text agents from voice calls
  - Select agent by ID
  - Returns response synchronously with 30-second timeout
  
  
- **list_available_agents Tool**: List configured text agents
  - Discover available agents
  - Get agent metadata (name, specialization, model)

#### Repositories
- **TextAgentRepository**: Agent persistence and management
  - JSON-based storage in vagina_config.json
  - CRUD operations for agents
  

#### Services
- **TextAgentService**: Azure OpenAI Chat Completions integration
  - HTTP client for text completion API
  - Synchronous queries with a fixed 30-second timeout
  - Error handling and logging

#### UI Components
- **Agents Tab**: Complete text agent management interface
  - Grid/list view of agents
  - Create, edit, delete agents
  - Agent configuration forms
  - Azure OpenAI settings
  - Selection dialog

### Changed
- **Tool System**: Extended with new tool categories
  - Added `text_agent` category for text agent tools
  - Added `call` category for call control tools
  
- **Tool Context**: Expanded with new APIs
  - `TextAgentApi` for text agent operations
  - `CallApi` for call control
  
- **ToolSandboxManager**: Enhanced with new host APIs
  - `TextAgentHostApi` for routing text agent requests
  - `CallHostApi` for call control requests

### Documentation
- Added comprehensive user guide: `docs/features/text_agents.md`
- Added voice agent tools documentation: `docs/features/voice_agent_tools.md`
- Added architecture guide: `docs/development/text_agent_architecture.md`
- Added API reference: `docs/api/text_agent_api.md`
- Added tool development guide: `docs/development/tool_development.md`
- Updated README.md with new features section

### Testing
- Added integration tests for text agent workflows: `test/integration/text_agent_integration_test.dart`
- Added integration tests for call control: `test/integration/call_integration_test.dart`
- Added integration tests for tool interactions: `test/integration/tools_integration_test.dart`

## [1.0.0] - 2026-01-17

### Added
- Initial release of VAGINA (Voice AGI Notepad Agent)
- Real-time voice conversation with Azure OpenAI GPT-4o
- Realtime API integration with WebSocket
- Audio recording and playback
- Chat history with text display
- Notepad feature with AI-editable documents
- Tool system with builtin tools:
  - get_current_time
  - calculator
  - memory_save, memory_recall, memory_delete
  - document_read, document_overwrite, document_patch
  - notepad_list_tabs, notepad_get_metadata, notepad_get_content, notepad_close_tab
- Speed Dial system for character presets
- Character customization (emoji, name, voice, system prompt)
- Session management and history
- Cross-platform support (Android, iOS, Windows, Web)
- PWA support
- Dark mode UI
- Japanese/English bilingual interface

### Infrastructure
- Flutter 3.27.1 with fvm
- Riverpod for state management
- JSON-based local storage
- Repository pattern for data persistence
- Feature-first architecture
- Tool sandbox with isolate-based execution

---

## Version History

### Version 1.1.0 (2026-01-18)
**Theme**: Text Agent Integration  
**Focus**: Extended voice agents with powerful text-based AI assistants for deep reasoning and long-form content generation.

**Key Features**:
- Text Agent system (synchronous queries with 30-second timeout)
- Three voice-text agent collaboration tools

**Impact**: Voice agents can now delegate complex tasks to specialized text agents, enabling much more sophisticated workflows while keeping voice interactions natural and responsive.

### Version 1.0.0 (2026-01-17)
**Theme**: Initial Release  
**Focus**: Real-time voice conversation with AI notepad capabilities.

**Key Features**:
- Voice agent system
- Realtime API integration
- Notepad and tool system
- Speed Dial presets

---

## Upgrade Guide

### Upgrading from 1.0.0 to 1.1.0

#### For Users

1. **No Action Required**: The upgrade is backwards compatible
2. **New Features Available**: Access the Agents tab to configure text agents
3. **Azure OpenAI**: You'll need Azure OpenAI credentials with Chat Completions API access

#### For Developers

1. **Dependencies**: Run `flutter pub get` to update dependencies
2. **Database**: No migration needed - new keys are added to existing JSON store
3. **Breaking Changes**: None
4. **New Providers**: Text agent providers are available via Riverpod:
   - `textAgentServiceProvider`
   - `textAgentsProvider`

#### Configuration Changes

**New JSON Keys** (automatically added):
- `text_agents`: Array of configured text agents

**Example**:
```json
{
  "text_agents": []
  // existing keys remain unchanged
}
```

---

## Roadmap

### Version 1.2.0 (Planned)
- **Streaming Responses**: Real-time streaming for text agent responses
- **OpenAI API Support**: Direct OpenAI API in addition to Azure
- **Agent Templates**: Predefined agent configurations

### Version 1.3.0 (Planned)
- **Multi-Agent Workflows**: Chain multiple agents together
- **Agent Marketplace**: Share agent configurations
- **Cost Tracking**: Monitor API usage and costs

### Future Considerations
- WebRTC support for audio
- Voice cloning
- Custom tool plugins
- Multi-modal agents (image, document analysis)

---

## Breaking Changes

### Version 1.1.0
- None - fully backwards compatible with 1.0.0

---

## Security

### Version 1.1.0
- API keys stored locally (consider secure storage in future)
- All text agent operations require valid Azure credentials
- No API keys transmitted except to Azure OpenAI

---

## Known Issues

### Version 1.1.0
- No streaming support for text responses (planned for 1.2.0)

---

## Credits

**Development Team**: VAGINA Contributors  
**Special Thanks**: Azure OpenAI team for Realtime API support

---

## Links

- [GitHub Repository](https://github.com/yuki-js/vagina)
- [Documentation](docs/)
- [Issue Tracker](https://github.com/yuki-js/vagina/issues)

---

**Note**: This changelog follows [Keep a Changelog](https://keepachangelog.com/) principles. Each version includes:
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements
