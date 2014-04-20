/**
 * Implements the API for working with tag trees in the browser.
 */
library browser;

import 'package:viewtree/core.dart' as core;

import 'dart:async' show StreamSubscription;
import 'dart:collection' show HashMap;
import 'dart:convert' show Codec;
import 'dart:html';

part 'src/browser/dom.dart';
part 'src/browser/root.dart';
part 'src/browser/socket.dart';
