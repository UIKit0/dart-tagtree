part of render;

typedef void _InvalidateFunc(_AnimatedNode node);

/// A _Node records how a [Tag] was rendered in the most recent animation frame.
///
/// Each [RenderRoot] has a tree of nodes that records how the DOM was last rendered.
/// Between animation frames, the tree should match the DOM. When rendering an
/// animation frame, a [Transaction] updates the tree (in place) to the new state
/// of the DOM.
///
/// Performing this update is a way of calculating all the changes that need to be made
/// to the DOM. See Transaction and its mixins for the update calculation and
/// [DomUpdater] for the API used to send a stream of updates to the DOM.
///
/// There are two subclasses, [_AnimatedNode] and [_ElementNode]. An animated node has
/// a shadow tree recording the output from the last time it was rendered. To calculate
/// the current state of the DOM, we could recursively replace each animated node with its
/// shadow, resulting in a tree containing only element nodes.
///
/// Each node conceptually has an owner that rendered its input Tag. For top-level
/// nodes that aren't in a shadow tree, the owner is outside the framework and makes changes
/// by calling Root.mount(). For nodes inside a shadow tree, the owner is the [Animator] that
/// rendered the shadow tree.
abstract class _Node {
  /// The unique id used to find the node's HTML element.
  final String path;

  /// The depth of this node in the node tree (not in the DOM).
  final int depth;

  _Node(this.path, this.depth);

  bool get isMounted;
  void unmount();
}

class _AnimatedNode extends _Node implements PlaceDelegate {
  Animator anim;
  _InvalidateFunc _invalidate;
  Place _place;

  Tag renderedTag;
  _Node shadow;
  bool _isDirty = true;

  @override
  OnRendered onRendered;

  _AnimatedNode(String path, int depth, Tag tag, this.anim, this._invalidate) :
    super(path, depth) {
    _place = anim.start(tag);
    _place.mount(this);
  }

  @override
  void invalidate() {
    if (isMounted) {
      _invalidate(this);
      _isDirty = true;
    }
  }

  bool get isMounted => _place != null;

  Tag render(Tag currentTag) {
    _place.commitState();
    Tag shadow = anim.renderAt(_place, currentTag);
    renderedTag = currentTag;
    _isDirty = false;
    return shadow;
  }

  bool shouldCut(Tag nextTag, Animator nextAnim) {
    return anim.shouldCut(_place, nextTag, nextAnim);
  }

  bool isDirty(Tag next) {
    _isDirty = _isDirty || anim.shouldRender(renderedTag, next);
    return _isDirty;
  }

  void unmount() {
    renderedTag = null;
    shadow = null;

    _place.unmount();
    _place = null;
    _invalidate = null;
    anim = null;
  }
}

/// A node for a rendered HTML element.
class _ElementNode extends _Node {
  ElementTag tag;
  // May be a List<_Node>, String, or RawHtml.
  var children;

  _ElementNode(String path, int depth, this.tag) : super(path, depth);

  bool get isMounted => tag != null;

  PropsMap get props => tag.props;

  void unmount() {
    tag = null;
    children = null;
  }
}

/// Used to wrap text children in a span when emulating mixed content.
const ElementType _textType = const ElementType(#text, "span", const [innerType]);
