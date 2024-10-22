import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MyVideoPlayer extends StatelessWidget {
  const MyVideoPlayer({super.key});

  final htmlContent = '''
<script src="https://fast.wistia.com/embed/medias/lfvgk6yve1.jsonp" 
async></script><script src="https://fast.wistia.com/assets/external/E-v1.js"
async></script><div class="wistia_embed wistia_async_lfvgk6yve1 
seo=false videoFoam=false" 
style="height:100%;position:relative;width:100%"><div 
class="wistia_swatch" 
style="height:100%;left:0;opacity:0;overflow:hidden;position:absolute;top:0;
transition:opacity 200ms;width:100%;"><img 
src="https://fast.wistia.com/embed/medias/lfvgk6yve1/swatch" 
style="filter:blur(5px);height:100%;object-fit:contain;width:100%;" alt="" 
aria-hidden="true" onload="this.parentNode.style.opacity=1;" 
/></div></div>
  ''';

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        width: MediaQuery.of(context).size.width * 0.65,
        color: Colors.white,
        child: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: htmlContent,
            mimeType: 'text/html',
            encoding: 'utf-8',
          ),
        ),
      ),
    );
  }
}

// class MyVideoPlayer extends StatefulWidget {
//   @override
//   _MyVideoPlayerState createState() => _MyVideoPlayerState();
// }
//
// class _MyVideoPlayerState extends State<MyVideoPlayer> {
//   late VideoPlayerController _videoPlayerController;
//   late ChewieController _chewieController;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeVideoPlayer();
//   }
//
//   @override
//   void dispose() {
//     _videoPlayerController.dispose();
//     _chewieController.dispose();
//     super.dispose();
//   }
//
//   void _initializeVideoPlayer() {
//     _videoPlayerController = VideoPlayerController.asset(
//       'assets/help.mp4', // Update the path according to your asset location
//     );
//
//     _chewieController = ChewieController(
//       videoPlayerController: _videoPlayerController,
//       autoPlay: true,
//       looping: true,
//       aspectRatio: 1
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Center(
//         child: Chewie(
//           controller: _chewieController,
//         ));
//
//   }
// }
