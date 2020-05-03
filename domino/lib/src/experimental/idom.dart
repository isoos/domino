import 'dart:async';

import 'package:meta/meta.dart';

typedef LifecycleCallback<L> = Function(LifecycleEvent<L> element);
typedef DomEventFn<V> = Function(DomEvent<V> event);
typedef SlotFn = void Function(DomContext $d);

abstract class DomContext<L, V> {
  L get element;
  dynamic get pointer;

  void open(
    String tag, {
    String key,
    LifecycleCallback<L> onCreate,
    LifecycleCallback<L> onRemove,
  });

  void attr(String name, String value);
  void style(String name, String value);
  void clazz(String name, {bool present = true});

  void event(
    String name, {
    @required DomEventFn<V> fn,
    String key,
    bool tracked = true,
  });

  void text(String value);
  void innerHtml(String value);

  void skipNode();
  void skipRemainingNodes();

  void close({String tag});
}

abstract class LifecycleEvent<L> {
  L get element;

  void triggerUpdate();
}

abstract class DomEvent<V> {
  V get event;

  void triggerUpdate();
}


class BindedVar<T> {
  final T Function() _getValue;
  final Function (T) _setValue;
  
  final _controller = StreamController<T>.broadcast();
  Stream<T> get valueStream => _controller.stream;

  T get value => _getValue();
  set value(T val) {
    if(_getValue() != val) {
      _setValue(val);
      _controller.add(val);
    }
  }

  T _lastVar;
  void triggerUpdate() {
    final val = _getValue();
    if(val != _lastVar) {
      _lastVar = val;
      _controller.add(_getValue());
    }
  }
  void triggerListenOn(Stream stream) {
    stream.listen((data) {triggerUpdate();});
  }

  void listenOn(Stream<T> stream) {
    stream.listen((data) => value = data);
  }
  void bind(BindedVar<T> bindedVar) {
    bindedVar.listenOn(valueStream);
    listenOn(bindedVar.valueStream);
  }

  BindedVar(this._getValue, this._setValue);
}
