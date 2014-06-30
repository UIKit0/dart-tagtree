part of core;

/// A Template renders a view by substituting another View.
abstract class Template<V extends View> extends Animator<V,dynamic> {
  const Template();

  render(V view);

  @override
  Place start(V firstView) => new Place(false);

  @override
  View renderAt(V view, Place p) => render(view);

  // implement [CreateExpander].
  Template call() => this;
}

/// A view that renders itself using a template.
/// (It should be stateless; otherwise, use a regular View and a separate Expander for the state.)
abstract class TemplateView extends View {
  const TemplateView();

  Animator get animator => const _TemplateView();

  bool shouldRender(View prev) => true;

  View render();
}

class _TemplateView extends Template<TemplateView> {
  const _TemplateView();

  @override
  bool shouldRender(TemplateView prev, TemplateView next) => next.shouldRender(prev);

  @override
  View render(input) => input.render();

  toString() => "_TemplateView";
}
