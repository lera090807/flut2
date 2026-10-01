import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool _dirty = false;
bool _installed = false;
void setUnsavedChanges(bool value) {
  _dirty = value;
  if (_installed) return;
  _installed = true;
  web.window.addEventListener(
    'beforeunload',
    ((web.Event event) {
      if (_dirty) {
        event.preventDefault();
        (event as web.BeforeUnloadEvent).returnValue = '';
      }
    }).toJS,
  );
}
