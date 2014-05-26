part of render;

/// A Transaction renders one animation frame for one Root.
class _Transaction extends _Update {
  final Root root;
  final DomUpdater dom;
  final _HandlerMap handlers;

  // What to do
  final TagNode nextTagTree;
  final HandleFunc nextHandler;
  final List<_WidgetView> _widgetsToUpdate;

  _Transaction(this.root, this.dom, this.handlers, this.nextTagTree, this.nextHandler,
      Iterable<_WidgetView> widgetsToUpdate)
      : _widgetsToUpdate = new List.from(widgetsToUpdate);

  _InvalidateWidgetFunc get invalidateWidget => root._invalidateWidget;

  void run() {
    if (nextTagTree != null) {
      root._renderedTree = _replaceTree(root.path, root._renderedTree, nextTagTree);
    }

    // Sort ancestors ahead of children.
    _widgetsToUpdate.sort((a, b) => a.depth - b.depth);

    for (_WidgetView v in _widgetsToUpdate) {
      updateWidget(v);
    }

    _finish();
  }

  void _finish() {
    for (_View v in _mountedRefs) {
      dom.mountRef(v.path, v.ref);
    }

    for (_EltView form in _mountedForms) {
      dom.mountForm(form.path);
    }

    for (EventSink s in _mountedWidgets) {
      s.add(true);
    }

    for (EventSink s in _updatedWidgets) {
      s.add(true);
    }
  }

  /// Renders a tag tree and returns the new view tree.
  _View _replaceTree(String path, _View current, TagNode next) {
    if (current == null) {
      StringBuffer html = new StringBuffer();
      _View view = mountView(next, html, path, 0);
      dom.mount(html.toString());
      return view;
    } else {
      return updateOrReplace(current, next);
    }
  }

  // What was done

  @override
  void addHandler(HandlerType type, String path, val) {
    handlers.setHandler(type, path, _wrapHandler(val));
  }

  @override
  void setHandler(HandlerType type, String path, val) {
    handlers.setHandler(type, path, _wrapHandler(val));
  }

  @override
  void removeHandler(HandlerType type, String path) {
    handlers.removeHandler(type, path);
  }

  @override
  void releaseElement(String path, ref, {bool willReplace: false}) {
    dom.detachElement(path, ref, willReplace: willReplace);
    handlers.removeHandlersForPath(path);
  }

  HandlerFunc _wrapHandler(val) {
    if (val is HandlerFunc) {
      return val;
    } else if (val is Handler) {
      if (nextHandler == null) {
        throw "can't render a Handler without a handler function installed";
      }
      return (HandlerEvent e) {
        nextHandler(new HandlerCall(val, e));
      };
    } else {
      throw "can't convert to event handler: ${val.runtimeType}";
    }
  }
}
