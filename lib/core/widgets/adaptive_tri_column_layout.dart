import 'package:flutter/material.dart';

class AdaptiveTriColumnController {
  Future<void> Function(int index)? _goToPage;

  Future<void> goToLeft() => goToPage(0);

  Future<void> goToCenter() => goToPage(1);

  Future<void> goToRight() => goToPage(2);

  Future<void> goToPage(int index) async {
    final goToPage = _goToPage;
    if (goToPage == null) {
      return;
    }

    await goToPage(index);
  }

  void _attach(Future<void> Function(int index) goToPage) {
    _goToPage = goToPage;
  }

  void _detach(Future<void> Function(int index) goToPage) {
    if (_goToPage == goToPage) {
      _goToPage = null;
    }
  }
}

/// Responsive tri-column layout that preserves each column subtree while
/// switching between wide [`Row`](lib/core/widgets/adaptive_tri_column_layout.dart:105)
/// and narrow [`PageView`](lib/core/widgets/adaptive_tri_column_layout.dart:124)
/// presentations.
///
/// The three column widgets are expected to represent stable logical panes.
/// This widget keeps dedicated hosts for those panes so their local state can
/// survive layout-mode changes and offscreen paging.
class AdaptiveTriColumnLayout extends StatefulWidget {
  final Widget left;
  final Widget center;
  final Widget right;
  final VoidCallback onExitRequested;
  final int initialPage;
  final int leftFlex;
  final int centerFlex;
  final int rightFlex;
  final double wideLayoutBreakpoint;
  final Duration animationDuration;
  final Curve animationCurve;
  final AdaptiveTriColumnController? controller;

  const AdaptiveTriColumnLayout({
    super.key,
    required this.left,
    required this.center,
    required this.right,
    required this.onExitRequested,
    this.controller,
    this.initialPage = 1,
    this.leftFlex = 40,
    this.centerFlex = 30,
    this.rightFlex = 40,
    this.wideLayoutBreakpoint = 900,
    this.animationDuration = const Duration(milliseconds: 280),
    this.animationCurve = Curves.easeInOut,
  }) : assert(initialPage >= 0 && initialPage <= 2);

  @override
  State<AdaptiveTriColumnLayout> createState() =>
      _AdaptiveTriColumnLayoutState();
}

class _AdaptiveTriColumnLayoutState extends State<AdaptiveTriColumnLayout> {
  static const int _centerPageIndex = 1;

  late final PageController _pageController;
  late final GlobalKey<_TriColumnPageHostState> _leftColumnHostKey;
  late final GlobalKey<_TriColumnPageHostState> _centerColumnHostKey;
  late final GlobalKey<_TriColumnPageHostState> _rightColumnHostKey;
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _leftColumnHostKey =
        GlobalKey<_TriColumnPageHostState>(debugLabel: 'adaptive_tri_column_left');
    _centerColumnHostKey = GlobalKey<_TriColumnPageHostState>(
      debugLabel: 'adaptive_tri_column_center',
    );
    _rightColumnHostKey =
        GlobalKey<_TriColumnPageHostState>(debugLabel: 'adaptive_tri_column_right');
    widget.controller?._attach(_goToPage);
  }

  @override
  void didUpdateWidget(covariant AdaptiveTriColumnLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_goToPage);
      widget.controller?._attach(_goToPage);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(_goToPage);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToPage(int index) async {
    if (_currentPageIndex == index ||
        !_pageController.hasClients ||
        !_pageController.position.hasViewportDimension) {
      return;
    }

    await _pageController.animateToPage(
      index,
      duration: widget.animationDuration,
      curve: widget.animationCurve,
    );
  }

  void _handleBackButton() {
    if (_currentPageIndex != _centerPageIndex) {
      _goToPage(_centerPageIndex);
      return;
    }

    widget.onExitRequested();
  }

  bool get _canPop => _currentPageIndex == _centerPageIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideLayout =
            constraints.maxWidth >= widget.wideLayoutBreakpoint;

        return PopScope(
          canPop: isWideLayout ? true : _canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && !isWideLayout) {
              _handleBackButton();
            }
          },
          child: isWideLayout ? _buildWideLayout() : _buildNarrowLayout(),
        );
      },
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: widget.leftFlex,
          child: _buildLeftColumn(),
        ),
        Expanded(
          flex: widget.centerFlex,
          child: _buildCenterColumn(),
        ),
        Expanded(
          flex: widget.rightFlex,
          child: _buildRightColumn(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
        });
      },
      children: [
        _buildLeftColumn(),
        _buildCenterColumn(),
        _buildRightColumn(),
      ],
    );
  }

  // GlobalKey-backed hosts let the same pane subtree move between the wide Row
  // and narrow PageView without throwing away its local State.
  Widget _buildLeftColumn() {
    return _TriColumnPageHost(
      key: _leftColumnHostKey,
      child: widget.left,
    );
  }

  Widget _buildCenterColumn() {
    return _TriColumnPageHost(
      key: _centerColumnHostKey,
      child: widget.center,
    );
  }

  Widget _buildRightColumn() {
    return _TriColumnPageHost(
      key: _rightColumnHostKey,
      child: widget.right,
    );
  }
}

class _TriColumnPageHost extends StatefulWidget {
  final Widget child;

  const _TriColumnPageHost({
    super.key,
    required this.child,
  });

  @override
  State<_TriColumnPageHost> createState() => _TriColumnPageHostState();
}

class _TriColumnPageHostState extends State<_TriColumnPageHost>
    with AutomaticKeepAliveClientMixin<_TriColumnPageHost> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
