import 'dart:math';
import 'package:flutter/material.dart';
import '../models/hud_config.dart';
import '../theme/app_theme.dart';

/// Visual drag-and-drop HUD layout editor.
///
/// Shows a grid canvas (4 × 6 cells) representing the data page of the ride
/// screen. The user drags metric tiles from the palette at the bottom onto any
/// grid cell. Placed tiles can be re-dragged to a new cell or removed with the
/// ✕ button. Tap SAVE to persist the layout.
class HudGridEditorScreen extends StatefulWidget {
  final HudConfig config;

  const HudGridEditorScreen({super.key, required this.config});

  @override
  State<HudGridEditorScreen> createState() => _HudGridEditorScreenState();
}

class _HudGridEditorScreenState extends State<HudGridEditorScreen> {
  late List<HudWidgetPlacement> _placements;

  @override
  void initState() {
    super.initState();
    _placements = List.from(widget.config.placements);
  }

  // ─── Placement helpers ────────────────────────────────────────────────────

  HudWidgetPlacement? _placementAt(int col, int row) {
    for (final p in _placements) {
      if (p.col == col && p.row == row) return p;
    }
    return null;
  }

  void _placeMetric(HudMetric metric, int col, int row) {
    setState(() {
      _placements.removeWhere((p) => p.metric == metric);
      _placements.add(HudWidgetPlacement(metric: metric, col: col, row: row));
    });
  }

  void _removeMetric(HudMetric metric) =>
      setState(() => _placements.removeWhere((p) => p.metric == metric));

  Set<HudMetric> get _placedMetrics =>
      _placements.map((p) => p.metric).toSet();

  List<HudMetric> get _availableMetrics => HudMetric.values
      .where((m) => !_placedMetrics.contains(m))
      .toList();

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          widget.config.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'SAVE',
              style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHint(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellSize = _computeCellSize(constraints);
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Center(child: _buildCanvas(cellSize)),
                      const SizedBox(height: 16),
                      _buildPaletteSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _computeCellSize(BoxConstraints constraints) {
    final maxByWidth =
        (constraints.maxWidth - 32) / kHudGridCols;
    // Allow canvas to use at most 60 % of the available height
    final maxByHeight = (constraints.maxHeight * 0.60) / kHudGridRows;
    return min(maxByWidth, maxByHeight).floorToDouble().clamp(52.0, 88.0);
  }

  void _save() {
    Navigator.of(context).pop(
      widget.config.copyWith(placements: List.from(_placements)),
    );
  }

  // ─── Hint banner ──────────────────────────────────────────────────────────

  Widget _buildHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: const Text(
        'Drag metrics from the palette onto the grid  ·  ✕ to remove  ·  Re-drag to move',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  // ─── Grid canvas ──────────────────────────────────────────────────────────

  Widget _buildCanvas(double cellSize) {
    final canvasW = cellSize * kHudGridCols;
    final canvasH = cellSize * kHudGridRows;

    return Container(
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: const Color(0xFF090A0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Grid line overlay
            CustomPaint(
              size: Size(canvasW, canvasH),
              painter: _GridPainter(
                  cols: kHudGridCols,
                  rows: kHudGridRows,
                  cellSize: cellSize),
            ),
            // Drop targets and placed tiles
            for (int row = 0; row < kHudGridRows; row++)
              for (int col = 0; col < kHudGridCols; col++)
                Positioned(
                  left: col * cellSize,
                  top: row * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: _buildCell(col, row, cellSize),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int col, int row, double cellSize) {
    final placement = _placementAt(col, row);

    return DragTarget<HudMetric>(
      onWillAcceptWithDetails: (details) {
        final existing = _placementAt(col, row);
        // Accept if the cell is empty, or if the dragged metric is already here
        return existing == null || existing.metric == details.data;
      },
      onAcceptWithDetails: (details) => _placeMetric(details.data, col, row),
      builder: (context, candidates, rejected) {
        final isHighlighted = candidates.isNotEmpty;
        if (placement != null) {
          return _buildPlacedTile(placement, cellSize, isHighlighted);
        }
        return _buildEmptyCell(isHighlighted, cellSize);
      },
    );
  }

  Widget _buildEmptyCell(bool highlighted, double cellSize) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: highlighted
            ? Border.all(
                color: AppColors.accent.withValues(alpha: 0.60), width: 1.5)
            : null,
      ),
      child: highlighted
          ? const Center(
              child: Icon(Icons.add_rounded,
                  color: AppColors.accent, size: 20))
          : null,
    );
  }

  Widget _buildPlacedTile(
      HudWidgetPlacement p, double cellSize, bool highlighted) {
    return Draggable<HudMetric>(
      data: p.metric,
      feedback: Material(
        color: Colors.transparent,
        child: _buildTileFeedback(p.metric, cellSize),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.20),
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
      ),
      child: _buildTileContent(p.metric, cellSize, highlighted),
    );
  }

  Widget _buildTileContent(
      HudMetric metric, double cellSize, bool highlighted) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.accent.withValues(alpha: 0.28)
            : AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: highlighted ? 0.80 : 0.45),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _exampleValue(metric),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: cellSize * 0.30,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: cellSize * 0.12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Remove button
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _removeMetric(metric),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 11, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTileFeedback(HudMetric metric, double cellSize) {
    return Opacity(
      opacity: 0.85,
      child: Container(
        width: cellSize,
        height: cellSize,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppColors.accent.withValues(alpha: 0.80)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            metric.label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: cellSize * 0.14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Palette ───────────────────────────────────────────────────────────────

  Widget _buildPaletteSection() {
    final available = _availableMetrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            available.isEmpty ? 'ALL METRICS PLACED' : 'DRAG TO PLACE',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (available.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Remove a tile from the grid to make it available again.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          )
        else
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: available.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) =>
                  _buildPaletteItem(available[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildPaletteItem(HudMetric metric) {
    return Draggable<HudMetric>(
      data: metric,
      feedback: Material(
        color: Colors.transparent,
        child: _buildPaletteItemFeedback(metric),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildPaletteChip(metric),
      ),
      child: _buildPaletteChip(metric),
    );
  }

  Widget _buildPaletteChip(HudMetric metric) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _exampleValue(metric),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteItemFeedback(HudMetric metric) {
    return Opacity(
      opacity: 0.90,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.70)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.30),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _exampleValue(metric),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metric.label,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _exampleValue(HudMetric m) {
    switch (m) {
      case HudMetric.speed:     return '24.5';
      case HudMetric.distance:  return '12.4';
      case HudMetric.time:      return '1:23';
      case HudMetric.avgSpeed:  return '18.2';
      case HudMetric.maxSpeed:  return '32.1';
      case HudMetric.elevation: return '127';
    }
  }
}

// ─── Grid painter ──────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final double cellSize;

  const _GridPainter(
      {required this.cols, required this.rows, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Draw dashed vertical lines (skip edges — handled by the container border)
    for (int c = 1; c < cols; c++) {
      final x = c * cellSize;
      _drawDashedLine(canvas, paint, Offset(x, 0), Offset(x, size.height));
    }

    // Draw dashed horizontal lines (skip edges)
    for (int r = 1; r < rows; r++) {
      final y = r * cellSize;
      _drawDashedLine(canvas, paint, Offset(0, y), Offset(size.width, y));
    }

    // Column and row coordinate dots at intersections
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    for (int c = 1; c < cols; c++) {
      for (int r = 1; r < rows; r++) {
        canvas.drawCircle(Offset(c * cellSize, r * cellSize), 2.5, dotPaint);
      }
    }
  }

  void _drawDashedLine(
      Canvas canvas, Paint paint, Offset start, Offset end) {
    const dashLen = 4.0;
    const gapLen = 5.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = sqrt(dx * dx + dy * dy);
    final nx = dx / len;
    final ny = dy / len;
    double d = 0;
    bool drawing = true;
    while (d < len) {
      final segLen = drawing ? dashLen : gapLen;
      final end2 = d + segLen;
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + nx * d, start.dy + ny * d),
          Offset(start.dx + nx * min(end2, len),
              start.dy + ny * min(end2, len)),
          paint,
        );
      }
      d = end2;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cols != cols || old.rows != rows || old.cellSize != cellSize;
}
