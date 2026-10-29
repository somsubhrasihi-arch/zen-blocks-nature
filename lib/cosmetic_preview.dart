import 'package:flutter/material.dart';
import 'campaign.dart';
import 'customization.dart';
import 'cosmetic_paint.dart';
import 'clear_effect.dart';

class CosmeticLivePreview extends StatefulWidget {
  const CosmeticLivePreview({super.key, required this.item, required this.palette,
    required this.skin, this.reduceMotion = false});
  final ShopItem item;
  final GamePalette palette;
  final String skin;
  final bool reduceMotion;
  @override
  State<CosmeticLivePreview> createState() => _CosmeticLivePreviewState();
}
class _CosmeticLivePreviewState extends State<CosmeticLivePreview> with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.reduceMotion || MediaQuery.disableAnimationsOf(context)) { animation.stop(); animation.value = .45; }
    else if (!animation.isAnimating && widget.item.kind == CosmeticKind.effect) { animation.repeat(); }
  }
  @override
  void dispose() { animation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(20), child: ColoredBox(color: widget.palette.board,
    child: SizedBox(height: 200, width: double.infinity, child: Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: _PreviewBoard(widget.item.kind == CosmeticKind.skin ? widget.item.id.split(':').last : widget.skin, widget.palette)),
      if (widget.item.kind == CosmeticKind.effect) IgnorePointer(child: CustomPaint(painter: SparkPainter(animation,
        palette: widget.palette, effect: widget.item.id.split(':').last))),
    ]))));
}
class _PreviewBoard extends CustomPainter {
  _PreviewBoard(this.skin, this.palette);
  final String skin;
  final GamePalette palette;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = (size.width/10).clamp(16.0, 32.0).toDouble();
    final left = (size.width-unit*8)/2, top = (size.height-unit*4)/2;
    for (var y=0;y<4;y++) {
      for (var x=0;x<8;x++) {
        final rect=Rect.fromLTWH(left+x*unit,top+y*unit,unit,unit);
        canvas.drawRect(rect,Paint()..color=palette.grid..style=PaintingStyle.stroke..strokeWidth=.5);
        if (y>=2 || y==0 && x>=2 && x<=4 || y==1 && x==3) {
          paintCosmeticBlock(canvas,rect.deflate(1),palette.blocks[(y<2?2:(x~/2+y))%7],skin:skin);
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant _PreviewBoard old) => old.skin!=skin || old.palette!=palette;
}
