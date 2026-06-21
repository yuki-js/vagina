// Contract test entry-point for VhrpRealtimeAdapter (hosted mode).
//
// Runs the shared RealtimeAdapter contract suite against the VHRP adapter
// backed by FakeVhrpTransport + CBOR-injected S2C messages.  If this file is
// green alongside the OAI entry-point, both adapters satisfy the same
// behavioural contract — proving "warp transparency" (handoff doc §1.2, §9.2).
//
// Run: flutter test test/feat/call/services/realtime/contract/
//   or: flutter test test/feat/call/services/realtime/contract/vhrp_realtime_adapter_contract_test.dart

import 'vhrp_adapter_harness.dart';
import 'realtime_adapter_contract.dart';

void main() {
  runRealtimeAdapterContractTests(
    label: 'VhrpRealtimeAdapter (hosted)',
    createHarness: VhrpAdapterHarness.new,
  );
}
