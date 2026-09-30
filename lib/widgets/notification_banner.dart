import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

class _Note {
  const _Note(this.title, this.body, this.icon, this.color, this.onTap);

  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

/// Shows notifications as banners that slide down from the top of the screen.
/// Swipe one left, right or up to dismiss it, or tap it to open it. Banners
/// that arrive together are shown one after another.
class NotificationBanner {
  static final _queue = Queue<_Note>();
  static OverlayEntry? _entry;

  static void show(
    OverlayState? overlay, {
    required String title,
    required String body,
    IconData icon = Icons.notifications,
    Color color = Colors.orange,
    VoidCallback? onTap,
  }) {
    if (overlay == null) return;
    _queue.add(_Note(title, body, icon, color, onTap));
    if (_entry == null) _showNext(overlay);
  }

  static void _showNext(OverlayState overlay) {
    if (_queue.isEmpty || !overlay.mounted) return;
    final note = _queue.removeFirst();
    _entry = OverlayEntry(
      builder: (ctx) => _Banner(
        note: note,
        onDone: () {
          _entry?.remove();
          _entry = null;
          _showNext(overlay);
        },
      ),
    );
    overlay.insert(_entry!);
  }
}

class _Banner extends StatefulWidget {
  const _Banner({required this.note, required this.onDone});

  final _Note note;
  final VoidCallback onDone;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  static const _visibleFor = Duration(seconds: 6);

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    reverseDuration: const Duration(milliseconds: 250),
  );
  late final _slide = Tween(begin: const Offset(0, -1.5), end: Offset.zero).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
  );
  Timer? _timer;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(_visibleFor, _slideAway);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    widget.onDone();
  }

  Future<void> _slideAway() async {
    if (_finished) return;
    _timer?.cancel();
    await _controller.reverse();
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final theme = Theme.of(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SlideTransition(
              position: _slide,
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => _finish(),
                child: GestureDetector(
                  // Flick upwards to push the banner back off the top.
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -200) _slideAway();
                  },
                  onTap: () {
                    note.onTap?.call();
                    _slideAway();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: note.color.withValues(alpha: 0.2),
                              child: Icon(note.icon, color: note.color),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(note.body, style: theme.textTheme.bodyMedium),
                                  if (note.onTap != null)
                                    Text(
                                      'Tap to view · swipe to dismiss',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
