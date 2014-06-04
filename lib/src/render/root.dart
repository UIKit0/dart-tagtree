part of render;

bool _alwaysRender(before, after) => true;

typedef _Node _MakeNodeFunc(String path, int depth, View node);

/// A RenderRoot is a place on an HTML page where a tag tree may be rendered.
abstract class RenderRoot {
  final int id;
  Theme theme = new Theme();
  final _handlers = new _HandlerMap();
  _Node _renderedTree;

  bool _frameRequested = false;
  View _nextTagTree;
  final Set<_WidgetNode> _widgetsToUpdate = new Set();

  RenderRoot(this.id);

  /// A subclass hook called after DOM elements are mounted and we are ready
  /// to start listenering for events.
  void installEventListeners();

  /// A subclass hook that's called when the DOM needs to be rendered.
  void requestAnimationFrame(RenderFunc callback);

  /// The unique id for this Root.
  String get path => "/${id}";

  /// Sets the tag tree to be rendered on the next animation frame.
  /// (If called more than once between two frames, only the last call will
  /// have any effect.)
  void mount(View nextTagTree) {
    _nextTagTree = nextTagTree;
    _requestAnimationFrame();
  }

  /// Calls any event handlers that were present in the most recently
  /// rendered tag tree.
  void dispatchEvent(HandlerEvent e) => _dispatch(e, _handlers);

  _Node _makeNode(String path, int depth, View node) {
    assert(node.checked());

    if (node is _TextView) {
      return new _TextNode(path, depth, node);
    }

    TagDef def = theme.tagDefs[node.tag];
    if (def == null) {
      throw "tag not defined in theme: ${node.tag}";
    }

    if (def is ElementDef) {
      return new _ElementNode(path, depth, node, def.type);
    } else if (def is TemplateDef) {
      return new _TemplateNode(path, depth, node, def.render, def.shouldRender);
    } else if (def is WidgetDef) {
      return new _WidgetNode(path, depth, node, def.create);
    }

    throw "unknown TagDef type: ${def.runtimeType}";
  }

  /// Schedules a widget to be updated just before rendering the next frame.
  /// (That is, marks the Widget as "dirty".)
  void _invalidateWidget(_WidgetNode view) {
    assert(view.mounted);
    _widgetsToUpdate.add(view);
    _requestAnimationFrame();
  }

  void _requestAnimationFrame() {
    if (!_frameRequested) {
      _frameRequested = true;
      requestAnimationFrame(_render);
    }
  }

  void _render(DomUpdater dom) {
    _Transaction tx = new _Transaction(this, dom, _handlers, _nextTagTree, _widgetsToUpdate);

    _frameRequested = false;
    _nextTagTree = null;
    _widgetsToUpdate.clear();

    bool wasEmpty = _renderedTree == null;
    tx.run();
    if (wasEmpty) {
      installEventListeners();
    }

    // No widgets should be invalidated while rendering.
    assert(_widgetsToUpdate.isEmpty);
  }
}

class _TextView extends View {
  get tag => "__TextView";
  final String value;
  const _TextView(this.value);
}
