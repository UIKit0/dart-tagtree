library viewlet;

import 'dart:html';
import 'dart:convert';

// infrastructure

int idCounter = 0;
Map<String, View> idToTree = {};
Set<Widget> updated = new Set();

void mount(View tree, HtmlElement container) {
  StringBuffer out = new StringBuffer();
  String id = "/${idCounter}"; idCounter++;
  tree.mount(out, id, 0);
  _unsafeSetInnerHtml(container, out.toString());
  container.onClick.listen((MouseEvent e) {
    var target = e.target;
    if (target is Element) {
      // TODO: bubbling. For now, just exact match.
      String id = target.dataset["path"];
      Handler h = allHandlers[#onClick][id];
      if (h != null) {
        h(e);
        for (Widget w in updated) {
          w.refresh();
        }
      }
    }
  });
  idToTree[id] = tree;
}

Map<Symbol, String> allTags = {
  #Div: "div",
  #Span: "span"
};

typedef Handler(e);

Map<Symbol, Map<String, Handler>> allHandlers = {
  #onClick: {}
};

/// A View is a node in a view tree.
///
/// A View can can be an HTML Element ("Elt"), plain text ("Text"), or a Widget.
/// Each Widget generates its own "shadow" view tree, which may contain Widgets in turn.
///
/// Each View has a Map<Symbol, dynamic> containing its *props*, which are a generalization of
/// HTML attributes. These contain all the externally-provided arguments to the view.
///
/// In addition, some views may have internal state, which changes in response to events.
/// When a Widget changes state, its shadow view tree must be re-rendered.
abstract class View {
  String _path;
  int _depth;
  View();

  /// Writes the view tree to HTML and assigns an id to each View.
  ///
  /// The path should be a string starting with "/" and using "/" as a separator,
  /// for example "/asdf/1/2/3", chosen to ensure uniqueness in the DOM.
  /// The path of a child View is created by appending a suffix starting with "/" to its
  /// parent. When rendered to HTML, the path will show up as the data-path attribute.
  ///
  /// Any Widgets will be expanded (recursively). The root node in a Widget's
  /// shadow tree will be assigned the same path as the Widget (recursively).
  void mount(StringBuffer out, String path, int depth) {
    _path = path;
    _depth = depth;
  }

  /// Frees resources associated with this View, not including any DOM nodes.
  void unmount();

  String get path => _path;

  Map<Symbol,dynamic> get props;
}

/// A DOM element.
class Elt extends View {
  final String name;
  final Map<Symbol, dynamic> _props;
  List<View> _children; // non-null when Elt is mounted

  Elt(this.name, this._props) {
    for (Symbol key in props.keys) {
      var val = props[key];
      if (key == #inner || key == #clazz || allHandlers.containsKey(key)) {
        // ok
      } else {
        throw "property not supported: ${key}";
      }
    }
    var inner = _props[#inner];
    assert(inner == null || inner is String || inner is View || inner is List);
  }

  void mount(StringBuffer out, String path, int depth) {
    super.mount(out, path, depth);
    out.write("<${name} data-path=\"${path}\"");
    for (Symbol key in _props.keys) {
      var val = _props[key];
      if (allHandlers.containsKey(key)) {
        allHandlers[key][path] = val;
      } else if (key == #clazz) {
        String escaped = HTML_ESCAPE.convert(_makeClassAttr(val));
        out.write(" class=\"${escaped}\"");
      }
    }
    out.write(">");
    var inner = _props[#inner];
    if (inner == null) {
      // none
    } else if (inner is String) {
      out.write(HTML_ESCAPE.convert(inner));
    } else if (inner is View) {
      _mountChildren(out, [inner]);
    } else if (inner is List) {
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
      _mountChildren(out, inner);
    }
    out.write("</${name}>");
  }

  void _mountChildren(StringBuffer out, List<View> children) {
    _children = children;
    for (int i = 0; i < children.length; i++) {
      children[i].mount(out, "${path}/${i}", _depth + 1);
    }
  }

  void unmount() {
    for (Symbol key in allHandlers.keys) {
      Map m = allHandlers[key];
      m.remove(path);
    }
    if (_children != null) {
      for (View child in _children) {
        child.unmount();
      }
    }
  }

  Map<Symbol,dynamic> get props => _props;

  static _checkInner(inner) {
    if (inner == null || inner is String || inner is View) {
      // ok
    } else if (inner is List) {
      // Handle mixed content
      List<View> result = [];
      for (var item in inner) {
        if (item is String) {
          result.add(new Text(item));
        } else if (item is View) {
          result.add(item);
        } else {
          throw "bad item in inner: ${item}";
        }
      }
      return result;
    }
    throw "bad argument to inner: ${inner}";
  }

  static String _makeClassAttr(val) {
    if (val is String) {
      return val;
    } else if (val is List) {
      return val.join(" ");
    } else {
      throw "bad argument for clazz: ${val}";
    }
  }
}

/// Some text that appears as a root or as a child in a list of Html nodes
/// (mixed content). If an Html node has text as its only child, it's handled
/// as a special case.
class Text extends View {
  final String value;
  Text(this.value);

  void mount(StringBuffer out, String path, int depth) {
    super.mount(out, path, depth);
    // need to surround with a span to support incremental updates to a child
    out.write("<span data-path=${path}>${HTML_ESCAPE.convert(value)}</span>");
  }

  void unmount() {}

  Map<Symbol,dynamic> get props => {#value: value};
}

abstract class Widget extends View {
  Map<Symbol, dynamic> _props;
  dynamic _state, _nextState;
  View shadow;

  Widget(this._props);

  get firstState => null;

  get state => _state;

  set nextState(s) {
    _nextState = s;
  }

  void setState(Map updates) {
    if (_nextState == null) {
      _nextState = new Map.from(_state);
    }
    _nextState.addAll(updates);
    updated.add(this);
  }

  void mount(StringBuffer out, String path, int depth) {
    super.mount(out, path, depth);
    _state = firstState;
    shadow = render();
    shadow.mount(out, path, depth);
  }

  void unmount() {
    shadow.unmount();
    shadow = null;
  }

  View render();

  void refresh() {
    assert(_path != null);

    if (_nextState != null) {
      _state = _nextState;
      _nextState = null;
    }

    Element before = querySelector("[data-path=\"${_path}\"]");

    shadow.unmount();
    shadow = render();
    StringBuffer out = new StringBuffer();
    shadow.mount(out, _path, _depth);
    Element after = _unsafeNewElement(out.toString());

    before.replaceWith(after);
  }

  Map<Symbol, dynamic> get props => _props;
}

abstract class TagsApi {
  View Div({clazz, onClick, inner});
  View Span({clazz, onClick, inner});
}

class Tags implements TagsApi {
  noSuchMethod(Invocation inv) {
    if (inv.isMethod) {
      String tag = allTags[inv.memberName];
      if (tag != null) {
        if (!inv.positionalArguments.isEmpty) {
          throw "position arguments not supported for html tags";
        }
        return new Elt(tag, inv.namedArguments);
      }
    }
    throw new NoSuchMethodError(this,
        inv.memberName, inv.positionalArguments, inv.namedArguments);
  }
}

Element _unsafeNewElement(String html) {
  return new Element.html(html, treeSanitizer: _NullSanitizer.instance);
}

void _unsafeSetInnerHtml(HtmlElement elt, String html) {
  elt.setInnerHtml(html, treeSanitizer: _NullSanitizer.instance);
}

class _NullSanitizer implements NodeTreeSanitizer {
  static var instance = new _NullSanitizer();
  void sanitizeTree(Node node) {}
}