part of core;

typedef bool ShouldUpdateFunc(Props p, Props next);

/// Defines a custom tag that's rendered by expanding a template.
///
/// The render function should take a named parameter for each
/// of the Tag's props.
///
/// For increased performance, the optional shouldUpdate function may be
/// used to avoid expanding the template when no properties have changed.
///
/// If the custom tag should have internal state, use [defineWidget] instead.
TagDef defineTemplate({ShouldUpdateFunc shouldUpdate, Function render})
  => new TemplateDef._raw(shouldUpdate, render);

/// A wrapper allowing a template's props to be accessed as fields.
@proxy
class Props {
  final Map<Symbol, dynamic> _props;

  Props(this._props);

  noSuchMethod(Invocation inv) {
    if (inv.isGetter) {
      if (_props.containsKey(inv.memberName)) {
        return _props[inv.memberName];
      }
    }
    print("keys: ${_props.keys.join(", ")}");
    return super.noSuchMethod(inv);
  }
}