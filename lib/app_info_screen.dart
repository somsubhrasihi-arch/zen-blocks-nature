import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_policy.dart';
import 'arcade_ui.dart';
import 'customization.dart';
import 'playful_style.dart';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key,required this.palette});
  final GamePalette palette;
  GamePalette get p => palette.playful;
  Future<void> open(BuildContext context,String address) async {
    try { if(await launchUrl(Uri.parse(address),mode:LaunchMode.externalApplication)) return; } catch (_) {}
    await Clipboard.setData(ClipboardData(text:address));
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not open the browser. Link copied instead.')));
  }
  Widget section(String title,Widget child)=>Container(margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:p.panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:p.accent.withValues(alpha:.2))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(color:p.accent,fontSize:20,fontWeight:FontWeight.w800)),
      const SizedBox(height:10),child]));
  Widget button(String label,IconData icon,VoidCallback action)=>SizedBox(width:double.infinity,child:ArcadeButton(label:label,icon:icon,onPressed:action,
    accent:p.accent,surface:p.control,height:50));
  @override
  Widget build(BuildContext context)=>Theme(data:buddyTheme(p),child:Scaffold(backgroundColor:p.background.first,
    appBar:AppBar(backgroundColor:p.panel,title:const Text('About & privacy'),leading:Padding(padding:const EdgeInsets.all(6),
      child:ArcadeIconButton(tooltip:'Back',icon:Icons.arrow_back_rounded,onPressed:()=>Navigator.pop(context),palette:p))),
    body:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[
      section('T-BLOCK · $appVersion',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(gameTagline,style:TextStyle(color:p.muted,height:1.5)),const SizedBox(height:10),
        Text('Offline play · Earned coins · Saved on this device',style:TextStyle(color:p.muted,height:1.5)),
        const SizedBox(height:14),button('Report an issue',Icons.help_outline_rounded,()=>open(context,supportUrl)),
        const SizedBox(height:8),button('Open-source licences',Icons.description_outlined,()=>showLicensePage(context:context,applicationName:appDisplayName,applicationVersion:appVersion)),
      ])),
      section('Privacy policy',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        for(final item in privacySections)...[
          Text(item.title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700)),const SizedBox(height:6),
          SelectableText(item.body,style:TextStyle(color:p.muted,fontSize:14,height:1.5)),const SizedBox(height:18),
        ],
        button('View public privacy policy',Icons.open_in_new_rounded,()=>open(context,privacyPolicyUrl)),
      ])),
    ]))));
}
