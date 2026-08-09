import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Controls chat auto-follow without fighting the reader.
///
/// Streaming output follows the tail only while the user is already near it.
/// A deliberate upward scroll detaches auto-follow immediately; returning to
/// the bottom re-arms it. Programmatic scrolls are tracked separately so they
/// cannot be mistaken for user intent.
final class NazaChatScrollFollowController extends ChangeNotifier {
  NazaChatScrollFollowController({
    ScrollController? scrollController,
    this.tailThreshold = 92,
  }) : controller = scrollController ?? ScrollController() {
    controller.addListener(_onPositionChanged);
  }

  final ScrollController controller;
  final double tailThreshold;

  bool _followTail = true;
  bool _programmaticMove = false;
  bool _disposed = false;
  bool _streaming = false;
  double _lastPixels = 0;
  Timer? _coalesce;

  bool get followTail => _followTail;
  bool get streaming => _streaming;
  bool get showJumpToLatest => !_followTail && controller.hasClients;

  void setStreaming(bool value) {
    if (_streaming == value) return;
    _streaming = value;
    notifyListeners();
  }

  /// Feed scroll notifications from a NotificationListener around the chat
  /// list. User drag direction is the strongest signal for detaching.
  bool handleNotification(ScrollNotification notification) {
    if (_disposed || _programmaticMove || !controller.hasClients) return false;

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.forward && _followTail) {
        _setFollow(false);
      } else if (notification.direction == ScrollDirection.idle && _isNearTail()) {
        _setFollow(true);
      }
    } else if (notification is ScrollEndNotification && _isNearTail()) {
      _setFollow(true);
    }
    return false;
  }

  /// Called when streamed text changes height. Multiple token paints are
  /// coalesced into one end-of-frame jump to avoid animation queues/jank.
  void onStreamPaint() {
    if (!_followTail || _disposed) return;
    _coalesce?.cancel();
    _coalesce = Timer(const Duration(milliseconds: 18), () {
      if (_followTail) unawaited(scrollToLatest(animated: false));
    });
  }

  /// Explicit user action. This is the only path that forcibly re-enables tail
  /// following when the reader is detached.
  Future<void> jumpToLatest() async {
    _setFollow(true);
    await scrollToLatest(animated: true);
  }

  Future<void> scrollToLatest({bool animated = false}) async {
    if (_disposed || !controller.hasClients) return;
    final position = controller.position;
    final target = position.maxScrollExtent;
    if ((target - position.pixels).abs() < 0.5) return;

    _programmaticMove = true;
    try {
      if (animated) {
        await controller.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        controller.jumpTo(target);
      }
    } finally {
      _programmaticMove = false;
      if (_isNearTail()) _setFollow(true);
    }
  }

  /// Useful after switching conversations or creating a new chat. It resets
  /// reader intent but waits until layout has produced a scroll extent.
  void armForConversationTail() {
    _setFollow(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) unawaited(scrollToLatest(animated: false));
    });
  }

  void _onPositionChanged() {
    if (_disposed || !controller.hasClients) return;
    final pixels = controller.position.pixels;
    final delta = pixels - _lastPixels;
    _lastPixels = pixels;

    if (!_programmaticMove) {
      if (delta < -1.5 && _followTail) {
        _setFollow(false);
      } else if (_isNearTail() && !_followTail) {
        _setFollow(true);
      }
    }
  }

  bool _isNearTail() {
    if (!controller.hasClients) return true;
    final position = controller.position;
    return position.maxScrollExtent - position.pixels <= tailThreshold;
  }

  void _setFollow(bool value) {
    if (_followTail == value || _disposed) return;
    _followTail = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _coalesce?.cancel();
    controller.removeListener(_onPositionChanged);
    controller.dispose();
    super.dispose();
  }
}
