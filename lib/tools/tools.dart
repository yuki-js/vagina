import 'package:vagina/services/tools_runtime/tool.dart';

import 'builtin/calculation/calculator_tool.dart';
import 'builtin/document/document_overwrite_tool.dart';
import 'builtin/document/document_patch_tool.dart';
import 'builtin/document/document_read_tool.dart';
import 'builtin/system/get_current_time_tool.dart';
import 'builtin/memory/memory_delete_tool.dart';
import 'builtin/memory/memory_recall_tool.dart';
import 'builtin/memory/memory_save_tool.dart';
import 'builtin/notepad/notepad_close_tab_tool.dart';
import 'builtin/notepad/notepad_get_content_tool.dart';
import 'builtin/notepad/notepad_get_metadata_tool.dart';
import 'builtin/notepad/notepad_list_tabs_tool.dart';
import 'builtin/call/end_call_tool.dart';
import 'builtin/text_agent/get_text_agent_response_tool.dart';
import 'builtin/text_agent/list_available_agents_tool.dart';
import 'builtin/text_agent/query_text_agent_tool.dart';

abstract class Toolbox {
  final List<Toolbox> _chained = [];

  List<Tool> get tools {
    final allTools = <Tool>[];
    allTools.addAll(create());
    for (final chained in _chained) {
      allTools.addAll(chained.tools);
    }
    return allTools;
  }

  List<Tool> create();

  Toolbox chain(Toolbox next) {
    _chained.add(next);
    return this;
  }
}

class RootToolbox extends Toolbox {
  @override
  List<Tool> create() {
    return [
      CalculatorTool(),
      DocumentOverwriteTool(),
      DocumentPatchTool(),
      DocumentReadTool(),
      GetCurrentTimeTool(),
      MemoryDeleteTool(),
      MemoryRecallTool(),
      MemorySaveTool(),
      NotepadCloseTabTool(),
      NotepadGetContentTool(),
      NotepadGetMetadataTool(),
      NotepadListTabsTool(),
      EndCallTool(),
      GetTextAgentResponseTool(),
      ListAvailableAgentsTool(),
      QueryTextAgentTool(),
    ];
  }
}

Toolbox toolbox = RootToolbox();
