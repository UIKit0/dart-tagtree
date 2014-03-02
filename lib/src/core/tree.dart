part of core;

/// Callbacks to the ViewTree's environment.
abstract class TreeEnv {
  /// Requests that the given tree be re-rendered.
  void requestFrame(ViewTree tree);
}

/// A ViewTree contains state that's global to a mounted View and its descendants.
class ViewTree {
  final int id;
  final TreeEnv env;

  /// Renders the first frame of the tree. Postcondition: it is ready to receive events.
  ViewTree.mount(this.id, this.env, View root, NextFrame frame) {
    StringBuffer html = new StringBuffer();
    root.mount(html, "/${id}", 0);
    frame.mount(html.toString());
    _finishMount(root, frame);
  }

  /// Finishes mounting a subtree after the DOM is created.
  void _finishMount(View subtreeRoot, NextFrame frame) {
    subtreeRoot.traverse((View v) {
      if (v is Elt) {
        frame.attachElement(this, v._ref, v.path, v.tagName);
      } else if (v is Widget) {
        v._tree = this;
      }
      v.didMount();
    });
  }

  bool _inViewEvent = false;

  /// Calls any event handlers in this tree.
  /// On return, there may be some dirty widgets to be re-rendered.
  /// Note: widgets may also change state outside any event handler;
  /// for example, due to a timer.
  /// TODO: bubbling. For now, just exact match.
  void dispatchEvent(ViewEvent e) {
    if (_inViewEvent) {
      // React does this too; see EVENT_SUPPRESSION
      print("ignored ${e.type} received while processing another event");
      return;
    }
    _inViewEvent = true;
    try {
      print("\n### ${e.type}");
      if (e.targetPath != null) {
        EventHandler h = _allHandlers[e.type][e.targetPath];
        if (h != null) {
          h(e);
        }
      }
    } finally {
      _inViewEvent = false;
    }
  }

  Set<Widget> _dirty = new Set();
  Set<Widget> _updated = new Set();

  /// Re-renders the dirty widgets in this tree.
  void render(NextFrame frame) {
    assert(_updated.isEmpty);
    List<Widget> batch = new List.from(_dirty);
    _dirty.clear();

    // Sort ancestors ahead of children.
    batch.sort((a, b) => a._depth - b._depth);
    for (Widget w in batch) {
      w.update(null, this, frame);
    }

    for (Widget w in _updated) {
      w.didUpdate();
    }
    _updated.clear();

    // No widgets should be invalidated while rendering.
    assert(_dirty.isEmpty);
  }

  void _invalidate(Widget w) {
    if (_dirty.isEmpty) {
      env.requestFrame(this);
    }
    _dirty.add(w);
  }
}