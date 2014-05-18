import 'package:viewtree/core.dart';
import 'package:viewtree/browser.dart';

final $ = new TagMaker();

final Hello = new TemplateDef(
    render: ({String message}) => $.Div(inner: "Hello, ${message}")
);

main() => root("#container").mount(Hello(message: "world"));
