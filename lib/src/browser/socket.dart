part of browser;

/// A RemoteZone tag displays a stream of tag trees from a WebSocket.
///
/// The [src] prop contains the URL of the websocket to open.
/// The [placeholder] will be displayed until the websocket connects.
/// The [exports] prop contains TagMakers for the tags that may be
/// rendered by the remote session.
/// If not null, Tags within the zone will be rendered with the given
/// [theme].
///
/// All UI events within a RemoteZone are sent back to the remote session.
class RemoteZone extends AnimatedTag<Tag> {
  final Tag placeholder;
  final String src;
  final Jsonable request;
  final HtmlTagSet exports;
  final Theme theme;

  const RemoteZone({this.placeholder, this.src, this.request, this.exports, this.theme});

  @override
  bool checked() {
    assert(placeholder != null);
    assert(src != null);
    assert(request != null);
    assert(exports != null);
    return true;
  }

  @override
  Place start() => new _RemoteTagPlace(placeholder, src, request, exports);

  @override
  Tag renderAt(_RemoteTagPlace p) {
    p.configure(src, request, exports);
    if (theme != null) {
      return new ThemeZone(theme, p.state);
    } else {
      return p.state;
    }
  }
}

class _RemoteTagPlace extends Place<Tag> {
  String src;
  Jsonable request;
  HtmlTagSet tagSet;
  _Connection conn;

  _RemoteTagPlace(Tag firstState, String src, Jsonable request, HtmlTagSet tagSet) :
    super(firstState) {
    configure(src, request, tagSet);
    onCut = (_) {
      _close();
    };
  }

  void configure(String src, Jsonable request, HtmlTagSet tagSet) {


    if (this.src != src || this.request != request) {
      _close();

      send(call) => conn.send(call);
      var codec = tagSet.makeCodec(onCall: send);

      conn = new _Connection(this, src, request, codec);

    } else if (this.tagSet != tagSet && conn != null) {
      conn.codec = tagSet.makeCodec(onCall: conn.send);
    }

    this.src = src;
    this.request = request;
    this.tagSet = tagSet;
  }

  /// Called each time the server sends a new animation frame.
  void onFrameChanged(Tag nextFrame) {
    nextState = nextFrame;
  }

  /// Called whenever a callback function is called for an animation frame in the zone.

  void showStatus(String message) {
    print(message);
    nextState = tagSet.Div(inner: message);
  }

  void _close() {
    if (conn != null) {
      conn.close();
      conn = null;
    }
  }
}

class _Connection {
  final String url;
  final WebSocket ws;
  TaggedJsonCodec codec;

  bool opened = false;

  _Connection(_RemoteTagPlace place, String url, Jsonable request, this.codec) :
    this.url = url,
    this.ws = new WebSocket(url)
  {
    ws.onError.listen((_) {
      if (!opened) {
        place.showStatus("Can't connect to ${url}");
      } else {
        place.showStatus("Websocket error");
      }
    });

    ws.onOpen.listen((_) {
      send(request);
    });

    ws.onMessage.listen((MessageEvent e) {
      if (!opened) {
        print("websocket opened");
      }
      opened = true;
      place.onFrameChanged(codec.decode(e.data));
    });

    ws.onClose.listen((CloseEvent e) {
      if (!opened) {
        place.showStatus("Can't connect to ${url} (closed)");
      } else {
        place.showStatus("Disconnected from ${url}");
      }
    });
  }

  void send(Jsonable data) {
    String msg = codec.encode(data);
    ws.sendString(msg);
  }

  void close() {
    ws.close();
  }
}
