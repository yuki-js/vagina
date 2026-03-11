import 'package:vagina/services/tools_runtime/tool.dart';

import 'builtin/calculation/calculator_tool.dart';
import 'builtin/document/document_overwrite_tool.dart';
import 'builtin/document/document_patch_tool.dart';
import 'builtin/document/document_read_tool.dart';
import 'builtin/filesystem/fs_active_files_tool.dart';
import 'builtin/filesystem/fs_close_tool.dart';
import 'builtin/filesystem/fs_delete_tool.dart';
import 'builtin/filesystem/fs_list_tool.dart';
import 'builtin/filesystem/fs_move_tool.dart';
import 'builtin/filesystem/fs_open_tool.dart';
import 'builtin/system/get_current_time_tool.dart';
import 'builtin/call/end_call_tool.dart';
import 'builtin/spreadsheet/spreadsheet_add_rows_tool.dart';
import 'builtin/spreadsheet/spreadsheet_delete_rows_tool.dart';
import 'builtin/spreadsheet/spreadsheet_update_rows_tool.dart';
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
      FsListTool(),
      FsOpenTool(),
      FsCloseTool(),
      FsDeleteTool(),
      FsMoveTool(),
      FsActiveFilesTool(),
      GetCurrentTimeTool(),
      EndCallTool(),
      SpreadsheetAddRowsTool(),
      SpreadsheetDeleteRowsTool(),
      SpreadsheetUpdateRowsTool(),
      ListAvailableAgentsTool(),
      QueryTextAgentTool(),
    ];
  }
}

Toolbox toolbox = RootToolbox();
