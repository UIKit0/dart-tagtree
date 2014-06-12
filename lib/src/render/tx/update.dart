part of render;

/// A Transaction mixin that implements updating a node tree and the DOM.
abstract class _Update extends _Mount with _Unmount {

  // Dependencies
  DomUpdater get dom;

  // What was updated
  final List<EventSink> _renderedWidgets = [];
  void setHandler(HandlerType type, String path, HandlerFunc handler);
  void removeHandler(HandlerType type, String path);

  // Renders the given view into an existing node tree.
  // The node tree will either be updated in place, or it will
  // unmounted and a new node tree will be created.
  // Either way, updates the DOM and returns the new node tree.
  _Node updateOrReplace(_Node current, View toRender, Theme oldTheme, Theme newTheme) {
    var nextViewer = toRender.createViewerForTheme(newTheme);
    if (current.canUpdateInPlace(toRender, nextViewer)) {
      _updateInPlace(current, toRender, nextViewer, oldTheme, newTheme);
      return current;
    } else {
      String path = current.path;
      int depth = current.depth;
      unmount(current, willReplace: true);

      var html = new StringBuffer();
      _Node result = mountView(toRender, newTheme, html, path, depth);
      dom.replaceElement(path, html.toString());
      return result;
    }
  }

  /// Renders a Widget without any property changes.
  void updateWidget(_WidgetNode node, Theme oldTheme, Theme newTheme) {
    Widget w = node.controller.widget;
    var oldState = w.state;
    w.commitState();
    _renderWidget(node, node.view, oldState, oldTheme, newTheme);
  }

  /// Updates a node tree in place, by expanding a View.
  /// Assumes the node's theme didn't change.
  ///
  /// After the update, all nodes in the subtree point to their newly-rendered Views
  /// and the DOM has been updated.
  void _updateInPlace(_Node node, View newView, Viewer viewer,
                      Theme oldTheme, Theme newTheme) {
    View oldView = node.updateProps(newView);

    if (node is _TemplateNode) {
      if (oldTheme != newTheme || node.template != viewer ||
          node.template.shouldRender(oldView, node.view)) {
        node.template = viewer;
        _renderTemplate(node, oldTheme, newTheme);
      }
    } else if (node is _WidgetNode) {
      Widget w = node.controller.widget;
      var oldState = w.state;
      w.commitState();
      _renderWidget(node, oldView, oldState, oldTheme, newTheme);
    } else if (node is _TextNode) {
      _renderText(node, oldView);
    } else if (node is _ElementNode) {
      _renderElt(node, oldView.props, oldTheme, newTheme);
    } else {
      throw "cannot update: ${node.runtimeType}";
    }
  }

  void _renderTemplate(_TemplateNode node, Theme oldTheme, Theme newTheme) {
    View newShadow = node.template.render(node.view);
    node.shadow = updateOrReplace(node.shadow, newShadow, oldTheme, newTheme);
  }

  void _renderWidget(_WidgetNode node, View oldView, oldState, Theme oldTheme, Theme newTheme) {
    if (!node.controller.widget.shouldRender(oldView, oldState)) {
      return;
    }

    var c = node.controller;
    View newShadow = c.widget.render();
    node.shadow = updateOrReplace(node.shadow, newShadow, oldTheme, newTheme);

    // Schedule events.
    if (c.didRender.hasListener) {
      _renderedWidgets.add(c.didRender);
    }
  }

  void _renderText(_TextNode node, _TextView oldView) {
    String newValue = node.view.value;
    if (oldView.value != newValue) {
      dom.setInnerText(node.path, newValue);
    }
  }

  void _renderElt(_ElementNode elt, PropsMap oldProps, Theme oldTheme, newTheme) {
    _updateDomProperties(elt, oldProps);
    _updateInner(elt, oldTheme, newTheme);
  }

  /// Updates DOM attributes and event handlers of an Elt.
  void _updateDomProperties(_ElementNode elt, PropsMap oldProps) {
    ElementType eltType = elt.view.type;
    String path = elt.path;
    PropsMap newProps = elt.view.props;

    // Delete any removed props
    for (String key in oldProps.keys) {
      if (newProps[key] != null) {
        continue;
      }

      var propType = eltType.propsByName[key];
      if (propType is HandlerType) {
        removeHandler(propType, path);
      } else if (propType is AttributeType) {
        dom.removeAttribute(path, propType.propKey);
      }
    }

    // Update any new or changed props
    for (String key in newProps.keys) {
      var oldVal = oldProps[key];
      var newVal = newProps[key];
      if (oldVal == newVal) {
        continue;
      }

      var type = eltType.propsByName[key];
      if (type is HandlerType) {
        setHandler(type, path, newVal);
        continue;
      } else if (type is AttributeType) {
        String val = _makeDomVal(key, newVal);
        dom.setAttribute(path, type.propKey, val);
      }
    }
  }

  /// Updates the inner DOM and mount/unmounts children when needed.
  /// (Postcondition: _children and _childText are updated.)
  void _updateInner(_ElementNode elt, Theme oldTheme, Theme newTheme) {
    String path = elt.path;
    var newInner = elt.view.inner;

    if (newInner == null) {
      unmountInner(elt);
      dom.setInnerText(path, "");
    } else if (newInner is String) {
      if (newInner == elt.children) {
        return;
      }
      unmountInner(elt);
      dom.setInnerText(path, newInner);
      elt.children = newInner;
    } else if (newInner is RawHtml) {
      if (newInner == elt.children) {
        return;
      }
      unmountInner(elt);
      dom.setInnerHtml(path, newInner.html);
      elt.children = newInner;
    } else if (newInner is View) {
      _updateChildren(elt, path, [newInner], oldTheme, newTheme);
    } else if (newInner is Iterable) {
      List<View> children = [];
      for (var item in newInner) {
        if (item is String) {
          children.add(new _TextView(item));
        } else if (item is View) {
          children.add(item);
        } else {
          throw "bad item in inner: ${item}";
        }
      }
      _updateChildren(elt, path, children, oldTheme, newTheme);
    } else {
      throw "invalid new value of inner: ${newInner.runtimeType}";
    }
  }

  /// Updates the inner DOM and mounts/unmounts children when needed.
  /// (Postcondition: _children,  _childText, and _childHtml are updated.)
  void _updateChildren(_ElementNode elt, String path, List<View> newChildren,
                       Theme oldTheme, Theme newTheme) {
    if (!(elt.children is List)) {
      StringBuffer out = new StringBuffer();
      elt.children = expandInner(elt, newTheme, out, newChildren);
      dom.setInnerHtml(path, out.toString());
      return;
    }

    int oldLength = elt.children.length;
    int newLength = newChildren.length;
    int addedChildCount = newLength - oldLength;

    List<_Node> updatedChildren = [];
    // update or replace each child that's in both lists
    int endBoth = addedChildCount < 0 ? newLength  : oldLength;
    for (int i = 0; i < endBoth; i++) {
      _Node before = elt.children[i];
      View after = newChildren[i];
      assert(before != null);
      assert(after != null);
      updatedChildren.add(updateOrReplace(before, after, oldTheme, newTheme));
    }

    if (addedChildCount < 0) {
      // trim to new size
      for (int i = oldLength - 1; i >= newLength; i--) {
        dom.removeChild(path, i);
      }
    } else if (addedChildCount > 0) {
      // append  children
      for (int i = oldLength; i < newLength; i++) {
        _Node child = _mountNewChild(elt, newChildren[i], i, newTheme);
        updatedChildren.add(child);
      }
    }
    elt.children = updatedChildren;
  }

  _Node _mountNewChild(_ElementNode parent, View child, int childIndex, Theme newTheme) {
    var html = new StringBuffer();
    _Node view = mountView(child, newTheme, html,
        "${parent.path}/${childIndex}", parent.depth + 1);
    dom.addChildElement(parent.path, html.toString());
    return view;
  }
}