part of core;

/// A mixin that implements the 'inner' property of an Elt.
/// This can be text, a list of child views, or nothing.
/// (Mixed content isn't directly supported. Instead, strings
/// will automatically be wrapped in Text nodes.)
abstract class _Inner {

  // Non-null when the Elt is mounted and it has at least one child.
  List<View> _children = null;
  // Non-null when the Elt is mounted and it contains just text.
  String _childText = null;

  // The parent node's path.
  String get path;

  // The parent node's depth.
  int get depth;

  void _mountInner(StringBuffer out, inner, String innerHtml) {
    if (inner == null) {
      if (innerHtml != null) {
        // Assumes we are using a sanitizer. (Otherwise it would be unsafe!)
        out.write(innerHtml);
      }
    } else if (inner is String) {
      out.write(HTML_ESCAPE.convert(inner));
      _childText = inner;
    } else if (inner is View) {
      _children = _mountChildren(out, [inner]);
    } else if (inner is Iterable) {
      List<View> children = [];
      for (var item in inner) {
        if (item is String) {
          children.add(new Text(item));
        } else if (item is View) {
          children.add(item);
        } else {
          throw "bad item in inner: ${item}";
        }
      }
      _children = _mountChildren(out, children);
    }
  }

  List<View> _mountChildren(StringBuffer out, List<View> children) {
    if (children.isEmpty) {
      return null;
    }

    String parentPath = path;
    int childDepth = depth + 1;
    for (int i = 0; i < children.length; i++) {
      children[i].mount(out, "${parentPath}/${i}", childDepth);
    }
    return children;
  }

  void _unmountInner(NextFrame frame) {
    if (_children != null) {
      for (View child in _children) {
        child.unmount(frame);
      }
      _children = null;
    }
    _childText = null;
  }

  /// Updates the inner DOM and mount/unmounts children when needed.
  /// (Postcondition: _children and _childText are updated.)
  void _updateInner(String path, newInner, newInnerHtml, NextFrame frame) {
    if (newInner == null) {
      _unmountInner(frame);
      frame.visit(path);
      if (newInnerHtml != null) {
        frame.setInnerHtml(newInnerHtml);
      } else {
        frame.setInnerText("");
      }
    } else if (newInner is String) {
      if (newInner == _childText) {
        return;
      }
      _unmountInner(frame);
      print("setting text of ${path}");
      frame..visit(path)..setInnerText(newInner);
      _childText = newInner;
    } else if (newInner is View) {
      _updateChildren(path, [newInner], frame);
    } else if (newInner is Iterable) {
      List<View> children = [];
      for (var item in newInner) {
        if (item is String) {
          children.add(new Text(item));
        } else if (item is View) {
          children.add(item);
        } else {
          throw "bad item in inner: ${item}";
        }
      }
      _updateChildren(path, children, frame);
    } else {
      throw "invalid new value of inner: ${newInner.runtimeType}";
    }
  }

  /// Updates the inner DOM and mounts/unmounts children when needed.
  /// (Postcondition: _children and _childText are updated.)
  void _updateChildren(String path, List<View> newChildren, NextFrame frame) {

    if (_children == null) {
      StringBuffer out = new StringBuffer();
      _mountInner(out, newChildren, null);
      frame.visit(path);
      frame.setInnerHtml(out.toString());
      _children = newChildren;
      _childText = null;
      return;
    }

    List<View> updatedChildren = [];
    // update or replace each child that's in both lists
    int endBoth = _children.length < newChildren.length ? _children.length : newChildren.length;
    int childDepth = depth + 1;
    for (int i = 0; i < endBoth; i++) {
      View before = _children[i];
      assert(before != null);
      View after = newChildren[i];
      assert(after != null);
      if (before.canUpdateTo(after)) {
        // note: update may call frame.visit()
        before.update(after, frame);
        updatedChildren.add(before);
      } else {
        String childPath = "${path}/${i}";
        print("replacing ${childPath} from ${before.runtimeType} to ${after.runtimeType}");
        before.unmount(frame);
        var out = new StringBuffer();
        after.mount(out, childPath, childDepth);
        frame..visit(path)..replaceChildElement(i, out.toString());
        updatedChildren.add(after);
      }
    }

    int extraChildren = newChildren.length - _children.length;
    if (extraChildren < 0) {
      print("removing ${-extraChildren} children under ${path}");
      // trim to new size
      frame.visit(path);
      for (int i = _children.length - 1; i >= newChildren.length; i--) {
        frame.removeChild(i);
      }
    } else if (extraChildren > 0) {
      print("adding ${extraChildren} children under ${path}");
      // append  children
      frame.visit(path);
      for (int i = _children.length; i < newChildren.length; i++) {
        View after = newChildren[i];
        var out = new StringBuffer();
        after.mount(out, "${path}/${i}", childDepth);
        frame.addChildElement(out.toString());
        updatedChildren.add(after);
      }
    }
    _children = updatedChildren;
    _childText = null;
  }
}
