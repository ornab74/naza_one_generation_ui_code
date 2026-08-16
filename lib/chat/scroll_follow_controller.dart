// LLM-CONTEXT:BEGIN
// FILE: lib/chat/scroll_follow_controller.dart
// ROLE: Owns scroll follow controller behavior within the conversation subsystem.
// DOMAIN: conversation
// SECURITY-INVARIANT: Preserve turn identity, cancellation semantics, and encrypted-history ownership across async work.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollDirection;
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
  }) : controller = scrollController ?? ScrollController(),
       _ownsController = scrollController == null {
    controller.addListener(_onPositionChanged);
  }

  final ScrollController controller;
  final bool _ownsController;
  final double tailThreshold;

  bool _followTail = true;
  bool _programmaticMove = false;
  bool _disposed = false;
  bool _streaming = false;
  bool _scrollQueued = false;
  double _lastPixels = 0;

  bool get followTail => _followTail;
  bool get streaming => _streaming;
  bool get showJumpToLatest => !_followTail && controller.hasClients;

  void setStreaming(bool value) {
    if (_streaming == value) return;
    _streaming = value;
    notifyListeners();
  }

  bool handleNotification(ScrollNotification notification) {
    if (_disposed || _programmaticMove || !controller.hasClients) return false;

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.forward && _followTail) {
        _setFollow(false);
      } else if (notification.direction == ScrollDirection.idle &&
          _isNearTail()) {
        _setFollow(true);
      }
    } else if (notification is ScrollEndNotification && _isNearTail()) {
      _setFollow(true);
    }
    return false;
  }

  void onStreamPaint() {
    if (!_followTail || _disposed || _scrollQueued) return;

    // Coalesce all stream updates for the current frame into one tail move.
    // Using a post-frame callback avoids fighting layout while the latest text
    // chunk is still changing the scroll extent, which otherwise shows up as
    // small repeated viewport snaps during generation.
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      if (_disposed || !_followTail || !controller.hasClients) return;
      unawaited(scrollToLatest(animated: false));
    });
  }

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
          duration: const Duration(milliseconds: 180),
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
    controller.removeListener(_onPositionChanged);
    // The controller is injectable so a parent can coordinate scrolling with
    // another viewport. Only dispose controllers created by this object;
    // disposing an injected controller can invalidate an unrelated widget on
    // the next frame and is a particularly difficult lifecycle bug to trace.
    if (_ownsController) controller.dispose();
    super.dispose();
  }
}
