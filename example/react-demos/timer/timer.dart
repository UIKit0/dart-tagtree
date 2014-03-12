import 'dart:async' show Timer;
import 'package:viewtree/core.dart';
import 'package:viewtree/browser.dart';

final $ = new Tags();

void main() {
  mount(new TimerWidget(), "#container");
}

class TimerWidget extends Widget<TimerState> {
  Timer timer;

  TimerWidget() : super({});

  get firstState => new TimerState();

  didMount() {
    timer = new Timer.periodic(new Duration(seconds: 1), (t) => tick());
  }

  willUnmount() {
    timer.cancel();
  }

  tick() {
    nextState.secondsElapsed = state.secondsElapsed + 1;
  }

  View render() => $.Div(inner: "Seconds elapsed: ${state.secondsElapsed}");
}

class TimerState extends State {
  int secondsElapsed = 0;

  TimerState clone() {
    return new TimerState()
      ..secondsElapsed = secondsElapsed;
  }
}