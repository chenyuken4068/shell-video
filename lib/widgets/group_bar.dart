import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 模板库「分组悬浮底栏」
///
/// · 与主界面导航栏同一套柔光玻璃：高 64 / 圆角 32 / 左右 20 / 底 16
/// · 内容 = 前 3 个可见分组 + 「其他」；右侧导入按钮用**同款玻璃**
/// · 选中胶囊**可滑动**（同主界面手感：280ms easeOutBack）
/// · 点/滑到「其他」→ 底栏顶再往上 **20px** 弹卡片（Overlay，可点击、无溢出）
class GroupBar extends StatefulWidget {
  const GroupBar({
    super.key,
    required this.groups,
    required this.selected,
    required this.onChanged,
    required this.onImport,
    this.labelOf,
  });

  final List<String> groups;
  final String selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onImport;
  final String Function(String group)? labelOf;

  @override
  State<GroupBar> createState() => _GroupBarState();
}

class _GroupBarState extends State<GroupBar> with SingleTickerProviderStateMixin {
  static const _h = 64.0; // 底栏高度
  static const _gap = 20.0; // 卡片与底栏顶的间距
  static const _side = 20.0; // 左右边距
  static const _bottom = 16.0; // 底部边距
  static const _pad = 6.0; // 底栏内边距

  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 140),
  );

  OverlayEntry? _entry;
  double _dragDx = 0;

  String _label(String g) => widget.labelOf?.call(g) ?? g;

  List<String> get _top => widget.groups.take(3).toList();
  List<String> get _others => widget.groups.skip(3).toList();
  bool get _onOther => !_top.contains(widget.selected);

  List<String> get _items => [..._top, '其他'];

  @override
  void didUpdateWidget(covariant GroupBar old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected && _entry != null && _top.contains(widget.selected)) {
      _closeCard();
    }
  }

  void _openCard() {
    if (_entry != null) return;
    _card.forward(from: 0);
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() {});
  }

  void _closeCard() {
    final e = _entry;
    if (e == null) return;
    _entry = null;
    _card.reverse().whenComplete(e.remove);
    setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    _card.dispose();
    super.dispose();
  }

  void _tapItem(String g) {
    HapticFeedback.selectionClick(); // 同主界面柔光玻璃底栏的手感
    if (g == '其他') {
      if (_entry != null) {
        _closeCard();
      } else {
        _openCard();
      }
      return;
    }
    _closeCard();
    if (g != widget.selected) widget.onChanged(g);
  }

  void _pickOther(String g) {
    HapticFeedback.selectionClick();
    _closeCard();
    if (g != widget.selected) widget.onChanged(g);
  }

  /// 当前胶囊索引：卡片打开或选中项在其他里 → 停在「其他」上
  int get _pillIndex {
    if (_entry != null || _onOther) return 3;
    return _top.indexOf(widget.selected).clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = _items;

    return SizedBox(
      height: _h,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, cons) {
              final innerW = cons.maxWidth - _pad * 2;
              final itemW = innerW / 4;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _dragDx = 0,
                onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
                onHorizontalDragEnd: (_) {
                  if (_dragDx.abs() < 18) return;
                  final next = (_pillIndex + (_dragDx > 0 ? 1 : -1)).clamp(0, 3);
                  _tapItem(items[next]);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    // 与主界面悬浮底栏（LiquidGlassNavBar matte）完全一致的参数：
                    // tint 0.50 / blur 33 / border 0.55 1.5px
                    filter: ImageFilter.blur(sigmaX: 33, sigmaY: 33),
                    child: Container(
                      height: _h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: dark
                            ? const Color(0xFF12131A).withValues(alpha: .50)
                            : Colors.white.withValues(alpha: .50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: dark ? .34 : .10),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // ① 会滑动的胶囊（同主界面手感）
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutBack,
                            left: _pad + itemW * _pillIndex + 2,
                            top: 6,
                            width: itemW - 4,
                            height: _h - 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: dark
                                    ? Colors.white.withValues(alpha: .20)
                                    : Colors.black.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ② 图标 + 文字
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: _pad),
                            child: Row(
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _tapItem(items[i]),
                                      child: _itemLabel(
                                        dark: dark,
                                        selected: i == _pillIndex,
                                        label: items[i] == '其他' ? '其他' : _label(items[i]),
                                        icon: _iconFor(items[i]),
                                      ),
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
              );
            }),
          ),
          const SizedBox(width: 10),
          // ③ 导入按钮：与左侧同一套玻璃
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onImport();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                // 与底栏 / 主界面底栏同一套：blur 33
                filter: ImageFilter.blur(sigmaX: 33, sigmaY: 33),
                child: Container(
                  width: _h,
                  height: _h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: dark
                        ? const Color(0xFF12131A).withValues(alpha: .50)
                        : Colors.white.withValues(alpha: .50),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: dark ? .30 : .12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add,
                    size: 28,
                    color: dark ? Colors.white : const Color(0xFF111214),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 「其他」卡片：底栏顶再往上 20px ──
  Widget _buildOverlay(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: _bottom + _h - 4,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeCard,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          right: _side + _h + 10,
          bottom: _bottom + _h + _gap + 25, // 底栏顶上方 20px + 再上移 25px
          width: 240,
          child: AnimatedBuilder(
            animation: _card,
            builder: (context, child) {
              final v = _card.status == AnimationStatus.reverse
                  ? Curves.easeInCubic.transform(_card.value)
                  : Curves.easeOutCubic.transform(_card.value);
              return Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * 8),
                  child: Transform.scale(
                    scale: .96 + .04 * v,
                    alignment: Alignment.bottomRight,
                    child: child,
                  ),
                ),
              );
            },
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 33, sigmaY: 33),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: dark
                        ? const Color(0xFF12131A).withValues(alpha: .50)
                        : Colors.white.withValues(alpha: .50),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: dark ? .30 : .12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Text(
                          '其他分组',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white54 : Colors.black54,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      // 统一大小的分组卡：每行 3 个，等宽等高
                      for (final row in _chunk(_others, 3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              for (var i = 0; i < 3; i++)
                                Expanded(
                                  child: i < row.length
                                      ? _otherChip(dark, row[i])
                                      : const SizedBox.shrink(),
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
      ],
    );
  }

  List<List<String>> _chunk(List<String> list, int n) {
    final out = <List<String>>[];
    for (var i = 0; i < list.length; i += n) {
      out.add(list.sublist(i, (i + n) > list.length ? list.length : i + n));
    }
    return out;
  }

  Widget _otherChip(bool dark, String g) {
    final selected = g == widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _pickOther(g),
        child: Container(
          height: 40, // 统一高度
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? (dark ? Colors.white : Colors.black87)
                : (dark ? Colors.white.withValues(alpha: .10) : Colors.black.withValues(alpha: .06)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: .14) : Colors.black.withValues(alpha: .10),
            ),
          ),
          child: Text(
            _label(g),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? (dark ? const Color(0xFF111214) : Colors.white)
                  : (dark ? Colors.white : const Color(0xFF1C1D22)),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String g) {
    switch (g) {
      case '自制抠图':
        return Icons.content_cut;
      case '自制透明':
        return Icons.opacity;
      case '常用':
        return Icons.star_border;
      case '其他':
        return Icons.more_horiz;
      default:
        return Icons.smartphone;
    }
  }

  Widget _itemLabel({
    required bool dark,
    required bool selected,
    required String label,
    required IconData icon,
  }) {
    final fg = dark
        ? (selected ? Colors.white : Colors.white.withValues(alpha: .62))
        : (selected ? const Color(0xFF111214) : Colors.black.withValues(alpha: .55));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19, color: fg),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        ),
      ],
    );
  }
}
