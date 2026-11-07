import 'package:flutter/material.dart';
import 'arcade_ui.dart';
import 'board_touch.dart';
import 'cosmetic_paint.dart';
import 'customization.dart';
import 'game.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.palette, required this.skin});
  final GamePalette palette;
  final String skin;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}
class _PracticeScreenState extends State<PracticeScreen> {
  final ZenGame game = ZenGame();
  int step = 0;
  bool done = false;
  String? hint;
  GamePalette get p => widget.palette;
  @override
  void initState() { super.initState(); setup(); }
  void setup() {
    game.reset(); game.start();
    game.active = Piece(step == 2 ? 0 : 2,
      shapes[step == 2 ? 0 : 2].map((r) => List<int>.from(r)).toList(), 3, 12);
    if (step == 2) game.board[19] = [1,1,1,1,1,1,0,0,0,0];
  }
  void move(int direction) {
    if (done) return;
    setState(() { if (game.move(direction, 0) && step == 0) done = true; });
  }
  void rotate() {
    if (done) return;
    setState(() { game.rotate(); if (step == 1) done = true; });
  }
  void drop() {
    if (done || step != 2) return;
    setState(() {
      game.hardDrop();
      if (game.lines > 0) { done = true; hint = null; }
      else { setup(); hint = 'Almost! Move the piece into the four empty squares on the right.'; }
    });
  }
  Widget button(String label, IconData icon, VoidCallback? onPressed, {bool primary=false}) => ArcadeButton(
    label: label, icon: icon, onPressed: onPressed, accent: p.accent, surface: p.control, primary: primary, height: 50);
  @override
  void dispose() { game.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: p.background.first,
    appBar: AppBar(backgroundColor: p.panel, title: const Text('Practice'),
      leading: Padding(padding: const EdgeInsets.all(6), child: ArcadeIconButton(tooltip:'Leave practice',icon:Icons.arrow_back_rounded,
        onPressed:()=>Navigator.pop(context,false),palette:p))),
    body: SafeArea(child: ListView(padding:const EdgeInsets.all(20),children:[
      Text('STEP ${step+1} OF 3',style:TextStyle(color:p.accent,fontSize:12,fontWeight:FontWeight.w800,letterSpacing:1.5)),
      const SizedBox(height:8),Text(['Make your move','Find the fit','Clear your first row'][step],style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
      const SizedBox(height:8),Text([
        'Tap Left or Right, or drag across the practice board.',
        'Tap Rotate, or tap the board to turn your piece.',
        'Move right to match the gap. Tap Drop or swipe down to complete the row.',
      ][step],style:TextStyle(color:p.muted,height:1.45)),
      const SizedBox(height:14),
      Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:300),child:GameBoardFrame(palette:p,
        child:AspectRatio(aspectRatio:1,child:BoardTouchControls(enabled:!done,onRotate:rotate,onMove:move,onDrop:drop,
          child:CustomPaint(key:const ValueKey('practice-board'),painter:_PracticePainter(game,p,widget.skin),size:Size.infinite)))))),
      const SizedBox(height:14),Row(children:[Expanded(child:button('Left',Icons.arrow_back_rounded,done?null:()=>move(-1))),const SizedBox(width:8),
        Expanded(child:button('Rotate',Icons.rotate_right_rounded,done?null:rotate)),const SizedBox(width:8),
        Expanded(child:button('Right',Icons.arrow_forward_rounded,done?null:()=>move(1)))]),
      const SizedBox(height:8),if(step==2) button('Drop',Icons.keyboard_double_arrow_down_rounded,done?null:drop,primary:true),
      if(hint!=null) Padding(padding:const EdgeInsets.only(top:10),child:Text(hint!,style:TextStyle(color:p.blocks[1],height:1.4))),
      const SizedBox(height:14),
      if(done) ...[Text(step==2?'Perfect! You cleared a row.':'Nice! You’ve got it.',textAlign:TextAlign.center,
        style:TextStyle(color:p.accent,fontWeight:FontWeight.w800)),const SizedBox(height:10),
        button(step==2?'Finish practice':'Next step',Icons.check_rounded,(){
          if(step==2){Navigator.pop(context,true);}else{setState((){step++;done=false;hint=null;setup();});}
        },primary:true)],
      const SizedBox(height:12),Text('Take your time. Practice does not change your scores, coins or saved game.',textAlign:TextAlign.center,
        style:TextStyle(color:p.muted,fontSize:12,height:1.4)),
    ])));
}
class _PracticePainter extends CustomPainter {
  _PracticePainter(this.game,this.palette,this.skin);
  final ZenGame game;
  final GamePalette palette;
  final String skin;
  @override
  void paint(Canvas canvas,Size size) {
    final unit=size.width/10, cells=game.visibleBoard, ghost=game.ghostPiece;
    for(var y=10;y<20;y++)for(var x=0;x<10;x++){
      final rect=Rect.fromLTWH(x*unit,(y-10)*unit,unit,unit);
      canvas.drawRect(rect,Paint()..color=palette.grid..style=PaintingStyle.stroke..strokeWidth=.5);
      if(cells[y][x]>0) paintCosmeticBlock(canvas,rect.deflate(1),palette.blocks[cells[y][x]-1],skin:skin);
    }
    if(ghost!=null)for(var r=0;r<ghost.cells.length;r++)for(var c=0;c<ghost.cells[r].length;c++){
      final y=ghost.y+r,x=ghost.x+c;
      if(ghost.cells[r][c]==0||y<10||y>=20||cells[y][x]!=0)continue;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x*unit+2,(y-10)*unit+2,unit-4,unit-4),const Radius.circular(4)),
        Paint()..color=palette.accent.withValues(alpha:.6)..style=PaintingStyle.stroke..strokeWidth=1.5);
    }
  }
  @override
  bool shouldRepaint(covariant _PracticePainter old)=>true;
}
