import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:meal_app/config.dart';
import 'package:meal_app/models/order.dart';
import 'package:meal_app/screens/my_orders_screen.dart';
import 'package:meal_app/services/meal_service.dart';
import 'package:meal_app/services/notification_service.dart';
import 'package:meal_app/services/order_service.dart';

/// Live, animated order tracking. The story (chef cooking, rider picking up
/// and delivering, customer eating) only moves forward as far as the admin has
/// moved the real order, and waits at each step until the next one.
class OrderTrackerScreen extends StatefulWidget {
  const OrderTrackerScreen({super.key, required this.orderId, this.orderStream});

  final String orderId;

  /// For tests; defaults to the live order from Firestore.
  final Stream<MealOrder?>? orderStream;

  @override
  State<OrderTrackerScreen> createState() => _OrderTrackerScreenState();
}

class _Step {
  const _Step(this.label, this.icon, this.title, this.start);

  final String label;
  final IconData icon;
  final String title;
  final double start; // story seconds
}

const _storyLength = 16.0;
// Each step starts just after where the previous status stops the story, so
// a story waiting at "confirmed" (2.0) isn't labelled "cooking".
const _steps = [
  _Step('Confirmed', Icons.receipt_long, 'Order confirmed!', 0),
  _Step('Cooking', Icons.soup_kitchen, 'The chef is cooking', 2.05),
  _Step('Picked up', Icons.shopping_bag, 'Rider picked up your order', 4.2),
  _Step('On the way', Icons.delivery_dining, 'On the way to you', 7.05),
  _Step('Delivered', Icons.home, 'Delivered! Enjoy your meal', 10),
];

/// How far the story plays for each status. The story then waits there,
/// with the chef still cooking or the rider still riding, until the admin
/// moves the order on.
double _storyTarget(OrderStatus status) => switch (status) {
      OrderStatus.pending => 0,
      OrderStatus.confirmed => 2.0,
      OrderStatus.cooking => 4.0, // chef cooking, before the meal pops out
      OrderStatus.pickedUp => 7.0, // meal on the bike, rider about to leave
      OrderStatus.onTheWay => 9.3, // riding, almost at the house
      OrderStatus.delivered => _storyLength,
      OrderStatus.rejected => 0,
    };

/// Progress of [s] through the window [a, b], from 0 to 1.
double _seg(double s, double a, double b, [Curve curve = Curves.linear]) =>
    curve.transform(((s - a) / (b - a)).clamp(0.0, 1.0));

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Point on a hop from [a] to [b] that rises [height] pixels in the middle.
Offset _arc(Offset a, Offset b, double t, double height) =>
    Offset.lerp(a, b, t)! - Offset(0, math.sin(math.pi * t) * height);

class _OrderTrackerScreenState extends State<OrderTrackerScreen> with TickerProviderStateMixin {
  /// Story position, 0–1 over [_storyLength] seconds.
  late final _story = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: (_storyLength * 1000) ~/ 1),
  );

  /// Always-running clock for idle motion (steam, bobbing, flames), so the
  /// scene stays alive while waiting for the next step.
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);

  StreamSubscription<MealOrder?>? _sub;
  MealOrder? _order;
  var _loaded = false;
  var _firstUpdate = true;

  double get _s => _story.value * _storyLength;

  String? _precached;

  /// Downloads the meal photo early so it isn't blank when it first pops up.
  void _precacheMealImage(MealOrder order) {
    final url = MealService.meals.value
        .where((m) => m.id == order.mealId)
        .map((m) => m.imageUrl)
        .firstOrNull;
    if (url == null || url == _precached) return;
    _precached = url;
    // A failed download is fine: the meal thumbnail falls back to 🍔.
    precacheImage(NetworkImage(url), context, onError: (_, _) {});
  }

  @override
  void initState() {
    super.initState();
    NotificationService.visibleOrderId = widget.orderId;
    _ticker = createTicker((elapsed) => _clock.value = elapsed.inMicroseconds / 1e6)..start();
    _sub = (widget.orderStream ?? OrderService.watchOrder(widget.orderId)).listen((order) {
      if (!mounted) return;
      setState(() {
        _order = order;
        _loaded = true;
      });
      if (order != null) {
        _precacheMealImage(order);
        _playTo(order.status, catchUp: _firstUpdate);
      }
      _firstUpdate = false;
    });
  }

  @override
  void dispose() {
    if (NotificationService.visibleOrderId == widget.orderId) {
      NotificationService.visibleOrderId = null;
    }
    _sub?.cancel();
    _ticker.dispose();
    _clock.dispose();
    _story.dispose();
    super.dispose();
  }

  void _playTo(OrderStatus status, {bool catchUp = false}) {
    final target = _storyTarget(status);
    if (status == OrderStatus.rejected || target <= _s) return;
    if (MediaQuery.of(context).disableAnimations) {
      _story.value = target / _storyLength;
      return;
    }
    // Catching up on an order that's already further along plays faster.
    final speed = catchUp ? 2.0 : 1.0;
    _story.animateTo(
      target / _storyLength,
      duration: Duration(milliseconds: ((target - _s) * 1000 / speed).round()),
      curve: Curves.linear,
    );
  }

  void _skip() {
    final order = _order;
    if (order != null) _story.value = _storyTarget(order.status) / _storyLength;
  }

  void _replay() {
    final order = _order;
    if (order == null) return;
    _story.value = 0;
    _playTo(order.status);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your order')),
        body: const Center(child: Text('This order no longer exists.')),
      );
    }

    final theme = Theme.of(context);
    final imageUrl = MealService.meals.value
        .where((m) => m.id == order.mealId)
        .map((m) => m.imageUrl)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your order'),
        actions: [
          AnimatedBuilder(
            animation: _story,
            builder: (ctx, _) => _story.isAnimating
                ? TextButton(onPressed: _skip, child: const Text('Skip'))
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_story, _clock]),
        builder: (ctx, _) {
          final s = _s;
          final waiting = order.status == OrderStatus.pending;
          final rejected = order.status == OrderStatus.rejected;
          final stepIndex = waiting || rejected
              ? -1
              : _steps.lastIndexWhere((step) => s >= step.start).clamp(0, _steps.length - 1);
          final finished = order.status == OrderStatus.delivered && !_story.isAnimating;

          final String title;
          final String subtitle;
          if (rejected) {
            title = 'Order rejected';
            subtitle = "Sorry, the restaurant couldn't take this order.";
          } else if (waiting) {
            title = 'Waiting for the restaurant';
            subtitle = "We'll start as soon as they confirm your order.";
          } else {
            title = _steps[stepIndex].title;
            subtitle = '${order.quantity} × ${order.mealTitle} · $kCurrency${order.total}';
          }

          return SafeArea(
            child: Column(
              children: [
                _StepTracker(
                  current: stepIndex,
                  progress: rejected ? 0 : s / _storyLength,
                  rejected: rejected,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: LayoutBuilder(
                        builder: (ctx, box) => Stack(
                          children: [
                            Positioned.fill(
                              child: _Scene(
                                s: s,
                                clock: _clock.value,
                                size: box.biggest,
                                imageUrl: imageUrl,
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: waiting || rejected ? 1 : 0,
                                  duration: const Duration(milliseconds: 400),
                                  child: rejected
                                      ? const _RejectedScene()
                                      : _WaitingScene(clock: _clock.value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(subtitle, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: finished
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _replay,
                                icon: const Icon(Icons.replay),
                                label: const Text('Replay'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (ctx) => const MyOrdersScreen()),
                                ),
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('My orders'),
                              ),
                            ),
                          ],
                        )
                      : order.status.isActive
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const _LiveDot(),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Live · moves on when the restaurant updates your order',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A small pulsing red dot that marks the tracker as live.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.3, end: 1.0).animate(_pulse),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
        ),
      );
}

class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.current, required this.progress, required this.rejected});

  final int current;
  final double progress;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: i == current ? 40 : 32,
                        height: i == current ? 40 : 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= current ? colors.primary : colors.surfaceContainerHighest,
                        ),
                        child: Icon(
                          _steps[i].icon,
                          size: i == current ? 22 : 18,
                          color: i <= current ? colors.onPrimary : colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _steps[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: i == current ? FontWeight.bold : FontWeight.normal,
                          color: i <= current ? colors.onSurface : colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: rejected ? colors.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks which scene(s) to show and cross-fades between them.
class _Scene extends StatelessWidget {
  const _Scene({required this.s, required this.clock, required this.size, required this.imageUrl});

  final double s;
  final double clock;
  final Size size;
  final String? imageUrl;

  static const _fade = 0.35;

  double _opacity(double start, double end, {bool fadeIn = true, bool fadeOut = true}) {
    if (s < start || s > end + _fade) return 0;
    final inT = fadeIn ? _seg(s, start, start + _fade) : 1.0;
    final outT = fadeOut ? 1 - _seg(s, end, end + _fade) : 1.0;
    return math.min(inT, outT);
  }

  @override
  Widget build(BuildContext context) {
    final layers = <(double, Widget)>[
      (_opacity(0, 2, fadeIn: false), _PlacedScene(p: _seg(s, 0, 2), size: size, clock: clock)),
      (_opacity(2, 5), _CookingScene(p: _seg(s, 2, 5), size: size, imageUrl: imageUrl, clock: clock)),
      (_opacity(5, 12), _StreetScene(u: (s - 5).clamp(0.0, 7.0), size: size, imageUrl: imageUrl, clock: clock)),
      (
        _opacity(12, _storyLength, fadeOut: false),
        _EatScene(p: _seg(s, 12, _storyLength), size: size, imageUrl: imageUrl, clock: clock),
      ),
    ];
    return Stack(
      children: [
        for (final (opacity, scene) in layers)
          if (opacity > 0) Positioned.fill(child: Opacity(opacity: opacity, child: scene)),
      ],
    );
  }
}

/// Places [child] so that its center is at [center].
Widget _at(Offset center, double size, Widget child) => Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      width: size,
      height: size,
      child: Center(child: child),
    );

Widget _emoji(String emoji, double size) =>
    Text(emoji, style: TextStyle(fontSize: size * 0.8, height: 1), textAlign: TextAlign.center);

class _MealThumb extends StatelessWidget {
  const _MealThumb({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.orange.shade100,
      child: Center(child: _emoji('🍔', size * 0.7)),
    );
    final url = imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: size * 0.06),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (ctx, error, stackTrace) => fallback),
      ),
    );
  }
}

// ── Waiting for confirmation / rejected ─────────────────────────────────────

class _WaitingScene extends StatelessWidget {
  const _WaitingScene({required this.clock});

  final double clock;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The hourglass flips over every two seconds.
    final turn = clock % 2;
    final angle = turn < 1.6 ? 0.0 : _seg(turn, 1.6, 2, Curves.easeInOut) * math.pi;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceContainer),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(angle: angle, child: _emoji('⏳', 96)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(
                        alpha: 0.3 + 0.7 * (math.sin(clock * 4 - i * 0.8) * 0.5 + 0.5),
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedScene extends StatelessWidget {
  const _RejectedScene();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer),
      child: Center(child: _emoji('😢', 110)),
    );
  }
}

// ── 1. Order confirmed ──────────────────────────────────────────────────────

class _PlacedScene extends StatelessWidget {
  const _PlacedScene({required this.p, required this.size, required this.clock});

  final double p;
  final Size size;
  final double clock;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final center = size.center(Offset.zero);
    final pop = _seg(p, 0, 0.45, Curves.elasticOut);
    final check = _seg(p, 0.3, 0.6, Curves.easeOutBack);
    // Gentle breathing once the receipt has landed.
    final breathe = p >= 1 ? 1 + math.sin(clock * 2.5) * 0.03 : 1.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.primaryContainer, colors.surfaceContainer],
        ),
      ),
      child: Stack(
        children: [
          // Sparkles orbiting the receipt.
          for (var i = 0; i < 8; i++)
            _at(
              center +
                  Offset.fromDirection(
                      i * math.pi / 4 + clock * 0.8, 70 + 50 * _seg(p, 0.2, 0.7, Curves.easeOut)),
              28,
              Opacity(
                opacity: _seg(p, 0.2, 0.4) * (p >= 1 ? 0.5 + 0.5 * math.sin(clock * 3 + i) : 1),
                child: _emoji('✨', 24),
              ),
            ),
          _at(
            center,
            150,
            Transform.scale(
              scale: pop * breathe,
              child: Container(
                width: 120,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: check,
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 56),
                    ),
                    const SizedBox(height: 8),
                    for (final width in [70.0, 50.0, 60.0])
                      Container(
                        width: width,
                        height: 6,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Chef cooking ─────────────────────────────────────────────────────────

class _CookingScene extends StatelessWidget {
  const _CookingScene({required this.p, required this.size, required this.imageUrl, required this.clock});

  final double p;
  final Size size;
  final String? imageUrl;
  final double clock;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final chef = Offset(w * 0.3, h * 0.55);
    final pan = Offset(w * 0.66, h * 0.6);
    final ready = _seg(p, 0.72, 0.95, Curves.elasticOut);
    final cooking = p < 0.75;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        ),
      ),
      child: Stack(
        children: [
          // Counter top.
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.72,
            bottom: 0,
            child: Container(color: const Color(0xFF8D6E63)),
          ),
          // Steam puffs rising from the pan.
          if (cooking)
            for (var i = 0; i < 4; i++)
              () {
                final t = (clock * 1.3 + i / 4) % 1;
                return _at(
                  pan + Offset(math.sin(t * 6 + i) * 12, -30 - t * 90),
                  30,
                  Opacity(
                    opacity: (1 - t) * 0.7,
                    child: Container(
                      width: 14 + t * 18,
                      height: 14 + t * 18,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                );
              }(),
          // Chef bobbing while stirring.
          _at(chef + Offset(0, math.sin(clock * 10) * 3), 110, _emoji('🧑‍🍳', 110)),
          // Flame under the pan.
          _at(
            pan + const Offset(0, 34),
            48,
            Transform.scale(
              scale: cooking ? 0.85 + 0.25 * math.sin(clock * 23).abs() : 0,
              child: _emoji('🔥', 44),
            ),
          ),
          // Pan shaking.
          _at(
            pan,
            80,
            Transform.rotate(angle: cooking ? math.sin(clock * 18) * 0.15 : 0, child: _emoji('🍳', 76)),
          ),
          // The finished meal pops out of the pan.
          if (ready > 0)
            _at(
              pan - Offset(0, 70 * ready),
              84,
              Transform.scale(scale: ready, child: _MealThumb(imageUrl: imageUrl, size: 76)),
            ),
          if (ready > 0.5)
            _at(pan + const Offset(46, -110), 40, Transform.scale(scale: ready, child: _emoji('⭐', 32))),
        ],
      ),
    );
  }
}

// ── 3–5. Pickup, ride and hand-off on the street ────────────────────────────

class _StreetScene extends StatelessWidget {
  const _StreetScene({required this.u, required this.size, required this.imageUrl, required this.clock});

  /// Story seconds since the street part started (0–7).
  final double u;
  final Size size;
  final String? imageUrl;
  final double clock;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final roadTop = h * 0.66;
    final roadBottom = h * 0.86;
    final roadMid = (roadTop + roadBottom) / 2;

    // Rider: arrives at the restaurant, waits for the meal, rides to the house.
    final double bikeX;
    if (u < 1.2) {
      bikeX = _lerp(-0.2, 0.26, _seg(u, 0, 1.2, Curves.easeOut));
    } else if (u < 2.0) {
      bikeX = 0.26;
    } else {
      bikeX = _lerp(0.26, 0.66, _seg(u, 2.0, 5.0, Curves.easeInOut));
    }
    // Also true while the story waits mid-ride, so the rider keeps riding.
    final moving = (u > 0 && u < 1.2) || (u > 2.0 && u < 5.0);
    final bob = moving ? math.sin(clock * 28) * 2.5 : 0.0;
    final bike = Offset(bikeX * w, roadMid - 30 + bob);
    final box = bike + const Offset(-20, -34); // delivery box on the back of the bike

    // Customer comes out of the house.
    final house = Offset(w * 0.88, roadTop - 34);
    final customerX = _lerp(0.9, 0.82, _seg(u, 5.0, 5.6, Curves.easeOut));
    final customer = Offset(customerX * w, roadTop - 30);
    final hands = customer + const Offset(-6, -4);

    // Meal: waits at the restaurant door, hops onto the bike, rides along,
    // then hops into the customer's hands.
    final door = Offset(w * 0.11 + 24, roadTop - 18);
    final Offset mealPos;
    if (u < 1.2) {
      mealPos = door;
    } else if (u < 2.0) {
      mealPos = _arc(door, box, _seg(u, 1.2, 2.0, Curves.easeInOut), 60);
    } else if (u < 5.6) {
      mealPos = box;
    } else {
      mealPos = _arc(box, hands, _seg(u, 5.6, 6.3, Curves.easeInOut), 70);
    }
    final received = u >= 6.3;

    return Stack(
      children: [
        // Sky.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF64B5F6), Color(0xFFBBDEFB)],
              ),
            ),
          ),
        ),
        _at(Offset(w * 0.82, h * 0.13), 60, Transform.rotate(angle: clock * 0.4, child: _emoji('☀️', 54))),
        // Drifting clouds.
        for (var i = 0; i < 3; i++)
          _at(
            Offset(((0.1 + i * 0.38 + clock * 0.03) % 1.25 - 0.1) * w, h * (0.12 + i * 0.08)),
            60,
            Opacity(opacity: 0.9, child: _emoji('☁️', 50 - i * 8.0)),
          ),
        // Grass.
        Positioned(
          left: 0,
          right: 0,
          top: roadTop - 6,
          bottom: 0,
          child: Container(color: const Color(0xFF66BB6A)),
        ),
        // Road with lane markings.
        Positioned(
          left: 0,
          right: 0,
          top: roadTop,
          height: roadBottom - roadTop,
          child: Container(color: const Color(0xFF424242)),
        ),
        for (var x = 0.0; x < w; x += 44)
          Positioned(
            left: x + 6,
            top: roadMid - 2,
            width: 22,
            height: 4,
            child: Container(color: Colors.white70),
          ),
        _at(Offset(w * 0.42, roadTop - 30), 60, _emoji('🌳', 56)),
        _at(Offset(w * 0.56, roadTop - 24), 46, _emoji('🌳', 42)),
        _at(Offset(w * 0.11, roadTop - 34), 76, _emoji('🏪', 72)),
        _at(house, 76, _emoji('🏡', 72)),
        // Dust puffs behind the moving bike.
        if (moving)
          for (var i = 0; i < 3; i++)
            () {
              final t = (clock * 3 + i / 3) % 1;
              return _at(
                bike + Offset(-34 - t * 30, 14 - t * 10),
                24,
                Opacity(
                  opacity: (1 - t) * 0.6,
                  child: Container(
                    width: 8 + t * 12,
                    height: 8 + t * 12,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              );
            }(),
        // Delivery rider: a helmeted rider sitting on the scooter (drawn first
        // so the scooter covers the lower half).
        _at(bike + Offset(6, -30 + (moving ? math.sin(clock * 28 + 1) * 1.5 : 0)), 40, _emoji('👷', 38)),
        _at(bike, 80, const Icon(Icons.delivery_dining, size: 72, color: Color(0xFFFF7043))),
        if (received)
          _at(
            bike + const Offset(10, -58),
            36,
            Transform.rotate(angle: math.sin(clock * 12) * 0.4, child: _emoji('👋', 30)),
          ),
        // Customer.
        if (u >= 5.0) _at(customer, 56, _emoji(received ? '🙋' : '🚶', 52)),
        if (received)
          for (var i = 0; i < 3; i++)
            () {
              final t = (clock * 1.2 + i / 3) % 1;
              return _at(
                customer + Offset(18 + math.sin(t * 6 + i) * 8, -40 - t * 50),
                24,
                Opacity(opacity: 1 - t, child: _emoji('❤️', 18)),
              );
            }(),
        // The meal.
        _at(mealPos, 40, _MealThumb(imageUrl: imageUrl, size: 34)),
      ],
    );
  }
}

// ── 6. Eating ───────────────────────────────────────────────────────────────

class _EatScene extends StatelessWidget {
  const _EatScene({required this.p, required this.size, required this.imageUrl, required this.clock});

  final double p;
  final Size size;
  final String? imageUrl;
  final double clock;

  static const _bites = [0.12, 0.28, 0.44, 0.60];
  static const _biteLength = 0.12;

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height;
    final face = Offset(w * 0.38, h * 0.48);
    final mouth = face + const Offset(26, 22);
    final plate = Offset(w * 0.7, h * 0.56);

    var bitesDone = 0;
    var mealPos = plate;
    var chomping = false;
    for (final b in _bites) {
      if (p >= b + _biteLength) {
        bitesDone++;
      } else if (p >= b) {
        final t = _seg(p, b, b + _biteLength);
        // Meal moves to the mouth and back.
        mealPos = Offset.lerp(plate, mouth, math.sin(math.pi * t))!;
        chomping = t > 0.35 && t < 0.65;
      }
    }
    final mealScale = 1 - bitesDone * 0.25;
    final finished = bitesDone == _bites.length;

    final String faceEmoji;
    if (p < _bites.first) {
      faceEmoji = '🤩';
    } else if (!finished) {
      faceEmoji = chomping ? '😮' : '😋';
    } else if (p < 0.85) {
      faceEmoji = '😍';
    } else {
      faceEmoji = '😌';
    }

    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [Color(0xFFFFE0B2), Color(0xFFFFB74D)], radius: 1.1),
            ),
          ),
        ),
        // Plate.
        _at(
          plate + const Offset(0, 34),
          120,
          Container(
            width: 116,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(60),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
            ),
          ),
        ),
        // Face, with a little bounce on every chomp.
        _at(face, 150, Transform.scale(scale: chomping ? 1.08 : 1, child: _emoji(faceEmoji, 140))),
        // Crumbs flying out of the mouth after each bite.
        for (final b in _bites)
          if (p > b + _biteLength * 0.5 && p < b + _biteLength * 1.6)
            for (var i = 0; i < 6; i++)
              () {
                final t = _seg(p, b + _biteLength * 0.5, b + _biteLength * 1.6);
                final dir = Offset.fromDirection(-math.pi / 2 + (i - 2.5) * 0.45, 30 + 40 * t);
                return _at(
                  mouth + dir + Offset(0, 40 * t * t),
                  10,
                  Opacity(
                    opacity: 1 - t,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: Colors.brown.shade400, shape: BoxShape.circle),
                    ),
                  ),
                );
              }(),
        // The meal getting smaller with each bite.
        if (!finished)
          _at(mealPos, 90, Transform.scale(scale: mealScale, child: _MealThumb(imageUrl: imageUrl, size: 80))),
        // Hearts keep floating up once it's all eaten.
        if (finished)
          for (var i = 0; i < 6; i++)
            () {
              final t = (clock * 0.45 + i / 6) % 1;
              return _at(
                face + Offset((i - 2.5) * 26 + math.sin(t * 8 + i) * 10, -70 - t * 90),
                30,
                Opacity(
                  opacity: (1 - t) * _seg(p, 0.72, 0.8),
                  child: _emoji(i.isEven ? '❤️' : '💛', 24),
                ),
              );
            }(),
        if (p > 0.66 && p < 1)
          Positioned.fill(child: CustomPaint(painter: _ConfettiPainter(_seg(p, 0.66, 1)))),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static final _pieces = () {
    final random = math.Random(7);
    const colors = [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple, Colors.pink];
    return List.generate(60, (i) => (
          x: random.nextDouble(),
          speed: 0.6 + random.nextDouble() * 0.8,
          spin: random.nextDouble() * 10,
          phase: random.nextDouble() * math.pi * 2,
          color: colors[i % colors.length],
          size: 5 + random.nextDouble() * 6,
        ));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final c in _pieces) {
      final y = -20 + t * size.height * 1.3 * c.speed;
      final x = c.x * size.width + math.sin(t * 8 + c.phase) * 18;
      paint.color = c.color.withValues(alpha: (1 - t * 0.6).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * c.spin);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: c.size, height: c.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
