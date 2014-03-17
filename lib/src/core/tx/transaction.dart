part of core;

/// A Transaction renders one animation frame for one Root.
class Transaction extends _Update {
  final Root root;
  final NextFrame frame;
  final EventDispatcher dispatcher;

  // What to do
  final View nextTop;
  final List<Widget> _widgetsToUpdate;

  Transaction(this.root, this.frame, this.dispatcher, this.nextTop, Iterable<Widget> widgetsToUpdate)
      : _widgetsToUpdate = new List.from(widgetsToUpdate);

  void run() {
    if (nextTop != null) {
      // Repace the entire tree.
      root._top = _updateRoot(root.path, root._top, nextTop);
    }

    // Sort ancestors ahead of children.
    _widgetsToUpdate.sort((a, b) => a.depth - b.depth);

    for (Widget w in _widgetsToUpdate) {
      update(w, null);
    }

    _finish();
  }

  void _finish() {
    for (Ref r in _mountedRefs) {
      frame.onRefMounted(r);
    }

    for (Elt form in _mountedForms) {
      frame.onFormMounted(root, form.path);
    }

    for (String path in _unmountedFormPaths) {
      frame.onFormUnmounted(path);
    }

    for (String path in _unmountedPaths) {
      frame.detachElement(path);
    }

    for (var w in _mountedWidgets) {
      w._didMount.add(true);
    }

    for (var w in _updatedWidgets) {
      w._didUpdate.add(true);
    }
  }

  // Returns the new top view.
  View _updateRoot(String path, View current, View next) {
    if (current == null) {
      StringBuffer html = new StringBuffer();
      mountView(next, html, path, 0);
      frame.mount(html.toString());
      return next;
    } else if (current.canUpdateTo(next)) {
      print("updating current view at ${path}");
      update(current, next);
      return current;
    } else {
      print("replacing current view ${path}");
      // Set the current element first because unmount clears the node cache
      frame.visit(path);
      unmount(current);

      var html = new StringBuffer();
      mountView(next, html, path, 0);
      frame.replaceElement(html.toString());
      return next;
    }
  }
}