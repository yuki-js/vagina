// Contract test entry-point for OaiRealtimeAdapter (standalone mode).
//
// Runs the shared RealtimeAdapter contract suite against the OAI adapter
// backed by FakeOaiTransport.  If this file is green, the standalone adapter
// satisfies the same behavioural contract as the hosted adapter — proving
// "warp transparency" (handoff doc §1.2, §9.2).
//
// Run: flutter test test/feat/call/services/realtime/contract/
//   or: flutter test test/feat/call/services/realtime/contract/oai_realtime_adapter_contract_test.dart

import 'oai_adapter_harness.dart';
import 'realtime_adapter_contract.dart';

void main() {
  runRealtimeAdapterContractTests(
    label: 'OaiRealtimeAdapter (standalone)',
    createHarness: OaiAdapterHarness.new,
  );
}
