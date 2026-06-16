import 'browser_history_stub.dart'
    if (dart.library.js_interop) 'browser_history_web.dart'
    as browser_history;

void clearBrowserUrlTransientParams() {
  browser_history.clearBrowserUrlTransientParams();
}
