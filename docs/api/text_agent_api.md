# Text Agent API Reference

## Overview

Complete API reference for the text agent system, including all models, services, repositories, and tool interfaces.

## Table of Contents

1. [Models](#models)
2. [Services](#services)
3. [Repositories](#repositories)
4. [Tool APIs](#tool-apis)
5. [OpenAI Function Schemas](#openai-function-schemas)
6. [Error Codes](#error-codes)

## Models

### TextAgent

**Location**: `lib/feat/text_agents/model/text_agent.dart`

Represents a configured text agent.

```dart
class TextAgent {
  final String id;
  final String name;
  final String? description;
  final AzureTextAgentConfig config;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TextAgent({
    required this.id,
    required this.name,
    this.description,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
  });

  TextAgent copyWith({...});
  Map<String, dynamic> toJson();
  factory TextAgent.fromJson(Map<String, dynamic> json);
}
```

**JSON Format**:
```json
{
  "id": "agent_1705612345678",
  "name": "Research Assistant",
  "description": "Helps with research and analysis",
  "config": { /* AzureTextAgentConfig */ },
  "createdAt": "2026-01-18T00:00:00.000Z",
  "updatedAt": "2026-01-18T00:00:00.000Z"
}
```

### AzureTextAgentConfig

**Location**: `lib/feat/text_agents/model/azure_text_agent_config.dart`

Azure OpenAI configuration.

```dart
class AzureTextAgentConfig {
  final String endpoint;
  final String apiKey;
  final String apiVersion;
  final String deploymentName;
  final int? maxTokens;
  final double? temperature;

  const AzureTextAgentConfig({
    required this.endpoint,
    required this.apiKey,
    required this.apiVersion,
    required this.deploymentName,
    this.maxTokens,
    this.temperature,
  });

  Map<String, dynamic> toJson();
  factory AzureTextAgentConfig.fromJson(Map<String, dynamic> json);
}
```

**JSON Format**:
```json
{
  "endpoint": "https://my-resource.openai.azure.com",
  "apiKey": "********************************",
  "apiVersion": "2024-10-21",
  "deploymentName": "gpt-4o-mini",
  "maxTokens": 1000,
  "temperature": 0.7
}
```

### TextAgentJob

**Location**: `lib/feat/text_agents/model/text_agent_job.dart`

Represents an async text agent job.

```dart
class TextAgentJob {
  final String id;
  final String agentId;
  final String prompt;
  final TextAgentExpectLatency expectLatency;
  final TextAgentJobStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final String? result;
  final String? error;

  TextAgentJob copyWith({...});
  Map<String, dynamic> toJson();
  factory TextAgentJob.fromJson(Map<String, dynamic> json);
}

enum TextAgentJobStatus {
  pending,
  running,
  completed,
  failed,
  expired,
}

enum TextAgentExpectLatency {
  instant,
  long,
  ultraLong,
}
```

**JSON Format**:
```json
{
  "id": "job_1705612345678_1234",
  "agentId": "agent_1705612345678",
  "prompt": "Write a market analysis",
  "expectLatency": "long",
  "status": "completed",
  "createdAt": "2026-01-18T00:00:00.000Z",
  "expiresAt": "2026-01-18T01:00:00.000Z",
  "completedAt": "2026-01-18T00:15:23.456Z",
  "result": "The market analysis results...",
  "error": null
}
```

## Services

### TextAgentService

**Location**: `lib/services/text_agent_service.dart`

HTTP client for Azure OpenAI Chat Completions API.

#### Constructor

```dart
TextAgentService({
  LogService? logService,
  http.Client? httpClient,
})
```

#### sendInstantQuery

Send a synchronous query that waits for the response.

```dart
Future<String> sendInstantQuery(
  TextAgent agent,
  String prompt, {
  Duration? timeout,
})
```

**Parameters**:
- `agent`: TextAgent to query
- `prompt`: User's query string
- `timeout`: Optional timeout (default: 30 seconds)

**Returns**: Response text from Azure OpenAI

**Throws**:
- `TimeoutException`: Request timed out
- `Exception`: Network or API errors

**Example**:
```dart
final service = TextAgentService();
final response = await service.sendInstantQuery(
  agent,
  'What is machine learning?',
  timeout: Duration(seconds: 20),
);
print(response); // "Machine learning is..."
```

#### sendAsyncQuery

Validate and generate token for async query.

```dart
Future<String> sendAsyncQuery(
  TextAgent agent,
  String prompt,
  TextAgentExpectLatency latency,
)
```

**Parameters**:
- `agent`: TextAgent to query
- `prompt`: User's query string
- `latency`: Expected latency tier

**Returns**: Job token string

**Throws**:
- `ArgumentError`: Invalid parameters (e.g., empty prompt)

**Example**:
```dart
final token = await service.sendAsyncQuery(
  agent,
  'Write a comprehensive report',
  TextAgentExpectLatency.ultraLong,
);
// token: "job_1705612345678_1234"
```

#### pollAsyncResult

Execute the actual HTTP request for async queries.

```dart
Future<String?> pollAsyncResult(
  TextAgent agent,
  String prompt,
  TextAgentExpectLatency latency,
)
```

**Parameters**:
- `agent`: TextAgent to query
- `prompt`: User's query string
- `latency`: Latency tier (determines timeout)

**Returns**: Response text or throws on error

**Throws**:
- `TimeoutException`: Request timed out
- `Exception`: Network or API errors

**Note**: This is typically called by `TextAgentJobRunner`, not directly by application code.

### TextAgentJobRunner

**Location**: `lib/services/text_agent_job_runner.dart`

Manages background execution of async jobs.

#### Constructor

```dart
TextAgentJobRunner({
  required TextAgentService textAgentService,
  required TextAgentRepository agentRepository,
  required TextAgentJobRepository jobRepository,
  LogService? logService,
})
```

#### initialize

Initialize the job runner. Call once during app startup.

```dart
Future<void> initialize()
```

**Side Effects**:
- Cleans up expired jobs
- Rehydrates pending jobs
- Starts periodic processing timer

**Example**:
```dart
final runner = ref.read(textAgentJobRunnerProvider);
await runner.initialize();
```

#### submitJob

Submit a new async job.

```dart
Future<String> submitJob(
  TextAgent agent,
  String prompt,
  TextAgentExpectLatency latency,
)
```

**Parameters**:
- `agent`: TextAgent to use
- `prompt`: User's query
- `latency`: Latency mode (long or ultraLong)

**Returns**: Job token for later retrieval

**Side Effects**:
- Creates job record in repository
- Triggers immediate processing attempt

**Example**:
```dart
final token = await runner.submitJob(
  agent,
  'Analyze market trends',
  TextAgentExpectLatency.long,
);
```

#### getJobStatus

Get current status of a job.

```dart
Future<TextAgentJob?> getJobStatus(String jobId)
```

**Parameters**:
- `jobId`: The job token

**Returns**: TextAgentJob or null if not found

**Example**:
```dart
final job = await runner.getJobStatus(token);
if (job?.status == TextAgentJobStatus.completed) {
  print(job!.result);
}
```

#### processJob

Process a specific job immediately.

```dart
Future<void> processJob(String jobId)
```

**Parameters**:
- `jobId`: The job token

**Side Effects**:
- Executes HTTP request
- Updates job status in repository
- Handles retries on failure

#### processAllPendingJobs

Process all pending and running jobs.

```dart
Future<void> processAllPendingJobs()
```

**Side Effects**:
- Processes each active job
- Marks expired jobs
- Implements retry logic

#### cleanupExpiredJobs

Mark expired jobs and optionally delete them.

```dart
Future<void> cleanupExpiredJobs()
```

**Side Effects**:
- Updates expired jobs to `expired` status
- Deletes expired jobs from storage

#### dispose

Stop background processing and clean up resources.

```dart
void dispose()
```

**Side Effects**:
- Cancels periodic timer
- Marks runner as not initialized

## Repositories

### TextAgentRepository

**Location**: `lib/interfaces/text_agent_repository.dart`

Abstract interface for text agent persistence.

```dart
abstract class TextAgentRepository {
  Future<void> save(TextAgent agent);
  Future<List<TextAgent>> getAll();
  Future<TextAgent?> getById(String id);
  Future<bool> update(TextAgent agent);
  Future<bool> delete(String id);
}
```

**Implementation**: `JsonTextAgentRepository` stores in `text_agents` key.

### TextAgentJobRepository

**Location**: `lib/interfaces/text_agent_job_repository.dart`

Abstract interface for job persistence.

```dart
abstract class TextAgentJobRepository {
  Future<void> save(TextAgentJob job);
  Future<List<TextAgentJob>> getAll();
  Future<TextAgentJob?> getById(String id);
  Future<void> delete(String id);
  Future<void> deleteExpired();
}
```

**Implementation**: `JsonTextAgentJobRepository` stores in `text_agent_jobs` key.

## Tool APIs

### TextAgentApi

**Location**: `lib/services/tools_runtime/apis/text_agent_api.dart`

Abstract API for text agent operations from tools.

```dart
abstract class TextAgentApi {
  Future<Map<String, dynamic>> sendQuery(
    String agentId,
    String prompt,
    String expectLatency,
  );
  
  Future<Map<String, dynamic>> getResult(String token);
  
  Future<List<Map<String, dynamic>>> listAgents();
}
```

#### sendQuery

Send a query to a text agent.

**Parameters**:
- `agentId`: Text agent ID
- `prompt`: Query string
- `expectLatency`: "instant", "long", or "ultra_long"

**Returns**:

For instant:
```dart
{
  "mode": "instant",
  "text": "The response...",
  "agentId": "agent_123"
}
```

For async:
```dart
{
  "mode": "async",
  "token": "job_...",
  "agentId": "agent_123",
  "pollAfterMs": 1500
}
```

#### getResult

Get result of async query.

**Parameters**:
- `token`: Job token

**Returns**:

Still running:
```dart
{
  "status": "running",
  "pollAfterMs": 1500
}
```

Completed:
```dart
{
  "status": "succeeded",
  "text": "The complete response..."
}
```

Failed:
```dart
{
  "status": "failed",
  "error": "Error message"
}
```

#### listAgents

List all available text agents.

**Returns**:
```dart
[
  {
    "id": "agent_1",
    "name": "Research Assistant",
    "description": "...",
    "specialization": "Research",
    "provider": "azureOpenAI",
    "model_or_deployment": "gpt-4o-mini"
  }
]
```

### CallApi

**Location**: `lib/services/tools_runtime/apis/call_api.dart`

Abstract API for call control from tools.

```dart
abstract class CallApi {
  Future<bool> endCall({String? endContext});
}
```

#### endCall

End the current call.

**Parameters**:
- `endContext`: Optional context string

**Returns**: `true` if successful

**Throws**: `Exception` on error

## OpenAI Function Schemas

### end_call Tool

```json
{
  "type": "function",
  "name": "end_call",
  "description": "End the current voice call. Use when conversation naturally concludes or user requests to end.",
  "parameters": {
    "type": "object",
    "properties": {
      "end_context": {
        "type": "string",
        "description": "Optional context about why the call is ending"
      }
    },
    "required": []
  }
}
```

### query_text_agent Tool

```json
{
  "type": "function",
  "name": "query_text_agent",
  "description": "Query a text-based AI agent for deep reasoning or knowledge.",
  "parameters": {
    "type": "object",
    "properties": {
      "agent_id": {
        "type": "string",
        "description": "ID of the text agent to query"
      },
      "prompt": {
        "type": "string",
        "description": "The query or prompt to send to the agent"
      },
      "expect_latency": {
        "type": "string",
        "enum": ["instant", "long", "ultra_long"],
        "description": "Expected response time"
      }
    },
    "required": ["agent_id", "prompt", "expect_latency"]
  }
}
```

### get_text_agent_response Tool

```json
{
  "type": "function",
  "name": "get_text_agent_response",
  "description": "Retrieve the response from a previously submitted async text agent query.",
  "parameters": {
    "type": "object",
    "properties": {
      "token": {
        "type": "string",
        "description": "The job token from query_text_agent"
      }
    },
    "required": ["token"]
  }
}
```

### list_available_agents Tool

```json
{
  "type": "function",
  "name": "list_available_agents",
  "description": "Get a list of all available text agents.",
  "parameters": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

## Error Codes

### Service Errors

| Code | Message | Description |
|------|---------|-------------|
| `TIMEOUT` | `Request timeout after Xs` | HTTP request timed out |
| `NETWORK_ERROR` | `Network error: ...` | Network connectivity issue |
| `API_ERROR` | `Azure OpenAI API error (XXX): ...` | Azure API returned error |
| `INVALID_RESPONSE` | `No choices in response` | Malformed API response |

### Tool Errors

| Code | Message | Description |
|------|---------|-------------|
| `MISSING_PARAMETER` | `Missing or empty required parameter: X` | Required parameter not provided |
| `INVALID_LATENCY` | `Invalid expect_latency value` | Latency not in enum |
| `AGENT_NOT_FOUND` | `Agent not found: X` | Agent ID doesn't exist |
| `JOB_NOT_FOUND` | `Job not found: X` | Job token doesn't exist |
| `JOB_EXPIRED` | `Job expired` | Job exceeded timeout |
| `QUERY_FAILED` | `Query failed: ...` | General query failure |

### Repository Errors

| Code | Message | Description |
|------|---------|-------------|
| `SAVE_FAILED` | `Failed to save agent` | Persistence error |
| `NOT_FOUND` | `Agent not found` | Agent doesn't exist |
| `DELETE_FAILED` | `Failed to delete agent` | Deletion error |

## HTTP API Details

### Azure OpenAI Chat Completions

**Endpoint**:
```
POST {endpoint}/openai/deployments/{deployment}/chat/completions?api-version={version}
```

**Headers**:
```
api-key: {apiKey}
Content-Type: application/json
```

**Request Body**:
```json
{
  "messages": [
    {
      "role": "user",
      "content": "{prompt}"
    }
  ],
  "max_tokens": 1000,
  "temperature": 0.7
}
```

**Response (200 OK)**:
```json
{
  "id": "chatcmpl-...",
  "object": "chat.completion",
  "created": 1705612345,
  "model": "gpt-4o-mini",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "The response text..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 50,
    "total_tokens": 60
  }
}
```

**Error Response (4xx/5xx)**:
```json
{
  "error": {
    "message": "Error description",
    "type": "invalid_request_error",
    "param": null,
    "code": "invalid_api_key"
  }
}
```

## Timeouts

| Latency Mode | Default Timeout | Configurable |
|--------------|----------------|--------------|
| instant | 30 seconds | Yes |
| long | 10 minutes | Yes |
| ultra_long | 60 minutes | Yes |

## Job Expiration

| Latency Mode | Expiration | After Expiration |
|--------------|-----------|------------------|
| instant | N/A | N/A (immediate) |
| long | 1 hour | Status: expired |
| ultra_long | 24 hours | Status: expired |

## Retry Strategy

**Retry Configuration**:
- Max retries: 3
- Initial delay: 5 seconds
- Max delay: 5 minutes
- Backoff: Exponential

**Retry Logic**:
```
Attempt 1: Immediate
Attempt 2: After 5 seconds
Attempt 3: After 10 seconds
Attempt 4: After 20 seconds (capped at 5 min)
```

**Retryable Errors**:
- Network timeouts
- HTTP 5xx errors
- Connection errors

**Non-retryable Errors**:
- HTTP 4xx errors (except 429)
- Invalid API key
- Malformed requests

## Rate Limiting

Azure OpenAI enforces rate limits:
- Requests per minute (RPM)
- Tokens per minute (TPM)

**Handling**:
- Service returns 429 status
- Implement exponential backoff
- Respect Retry-After header

## Related Documentation

- [User Guide](../features/text_agents.md)
- [Architecture Guide](../development/text_agent_architecture.md)
- [Voice Agent Tools](../features/voice_agent_tools.md)

---

**Last Updated**: 2026-01-18  
**Version**: 1.0.0
