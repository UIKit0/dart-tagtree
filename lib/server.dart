/**
 * Glue code connecting the ViewTree core with the dart:io library.
 */
library server;

import 'package:viewtree/core.dart' as core;

import 'dart:io';

abstract class ServerWidget extends core.View {
  ServerWidget() : super(null);

  core.View render();
}

/// A view tree container that renders to a WebSocket.
class WebSocketRoot {
  final WebSocket _socket;
  final core.JsonRuleSet _ruleSet;

  WebSocketRoot(this._socket, {core.JsonRuleSet rules}) :
      _ruleSet = (rules == null) ? core.Elt.rules : rules;

  /// Replaces the view with a new version.
  ///
  /// The previous view will be unmounted. Supports ServerWidget and Elts by default. Additional views
  /// may be supported by passing a JsonRuleSet in the contructor.
  void mount(core.View nextView) {
    while (!_canEncode(nextView)) {
      if (nextView is ServerWidget) {
        ServerWidget w = nextView;
        nextView = w.render();
      } else {
        throw "can't encode view: ${nextView.runtimeType}";
      }
    }
    String encoded = _ruleSet.encodeTree(nextView);
    _socket.add(encoded);
  }

  bool _canEncode(v) => (v is core.Jsonable) && _ruleSet.supportsTag(v.jsonTag);
}
