import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:dash_painter/dash_painter.dart';
import 'package:flutter/material.dart';
import 'package:levelthree/gamemanager.dart';
import 'package:levelthree/main.dart';
import 'package:levelthree/video_screen.dart';

class Game extends StatefulWidget {
  final GameManager gameManager = GameManager();
  final String player1Name;
  final String player2Name;
  final String player3Name;
  final bool levelFourMode;

  Game(
      this.player1Name, this.player2Name, this.player3Name, this.levelFourMode, {super.key});

  String getCurrentControllingPlayerName() {
    switch (gameManager.playerInControl) {
      case 1:
        return player1Name;
      case 2:
        return player2Name;
      case 3:
        return player3Name;
      default:
        return "ERROR";
    }
  }

  @override
  State<Game> createState() => GameState();
}

class EdgeForAnimation {
  int idx1;
  int idx2;

  EdgeForAnimation(this.idx1, this.idx2);

  @override
  bool operator ==(covariant EdgeForAnimation other) {
    if (identical(this, other)) return true;

    return idx1 == other.idx1 && idx2 == other.idx2;
  }

  @override
  int get hashCode => idx1.hashCode ^ idx2.hashCode;

  @override
  String toString() {
    return "EdgeForAnimation between $idx1 and $idx2";
  }
}

class GameState extends State<Game> with TickerProviderStateMixin {
  bool showingPassOverlay = true;
  int phase = 0;
  int selectionMode = -1;
  Packet? selectionOriginPacket;
  int selectionOriginIDX = -1;
  bool showingVictoryOverlay = false;
  bool showingDefeatOverlay = false;
  int packetsDelivered = 0;
  List<int> routersUsed = [];
  List<int> routersDisabled = [];
  int turnRouterDisabled = -1;

  late AnimationController pulseAnimationController;
  late Animation pulseAnimation;

  late AnimationController routerServerPulseAnimationController;
  late Animation routerServerPulseAnimation;

  Completer roundStartPopupCompleter = Completer();

  List<GlobalKey> computerAndRouterGlobalKeys = []; //GlobalKey
  double animationLeft = 0.0;
  double animationTop = 0.0;
  double animationHeight = 0.0;
  double animationWidth = 0.0;
  int animationState = -1;
  String animationTopText = "";
  String animationBottomText = "";
  Color animationColor = Colors.blue;
  bool animationIsHandshakePacket = false;
  bool animationIsFilePacket = false;
  int animationTo = -1;
  int animationFrom = -1;

  List<int> playerHappiness = [7,7,7];

  Map<EdgeForAnimation, List<Offset>> animationOffsets =
      <EdgeForAnimation, List<Offset>>{};

  List<GlobalKey> placeholderGlobalKeys =
      List<GlobalKey>.generate(11, (index) => GlobalKey());

  List<int> handshakesCompleted = [4];

  void playAudio(String audioToPlay, double volume) {
    AudioPlayer player = AudioPlayer();
    player.play(AssetSource(audioToPlay), volume: volume);
  }

  showVideo() {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: const MyVideoPlayer(),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Continue'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  late List<List<Packet>> packetList = [
    [
      Packet(1, 4, playerNames, globalKeys[0], false, true),
      // Packet(1, 4, playerNames, globalKeys[1], false, true),
      Packet(1, 4, playerNames, globalKeys[1], true, false)
    ],
    [],
    [],
    [],
    [],
    [
      Packet(2, 4, playerNames, globalKeys[2], false, true),
      // Packet(2, 4, playerNames, globalKeys[11], false, true),
      Packet(2, 4, playerNames, globalKeys[3], true, false)
    ],
    [],
    [
      Packet(3, 4, playerNames, globalKeys[4], false, true),
      // Packet(3, 4, playerNames, globalKeys[19], false, true),
      Packet(3, 4, playerNames, globalKeys[5], true, false)
    ],
    [],
    [],
    [Packet(5, 4, playerNames, globalKeys[6], true, false)]
  ];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 11; i++) {
      computerAndRouterGlobalKeys.add(GlobalKey()); //Key
      //.add(GlobalKey(debugLabel: "ComputerOrRouter" + i.toString()));
    }

    pulseAnimationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
          ..repeat(reverse: true);
    pulseAnimation =
        Tween(begin: 1.0, end: 5.0).animate(pulseAnimationController)
          ..addListener(() {
            setState(() {});
          });

    routerServerPulseAnimationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
          ..repeat(reverse: true);
    routerServerPulseAnimation =
        Tween(begin: 10.0, end: 30.0).animate(pulseAnimationController)
          ..addListener(() {
            setState(() {});
          });

    Random random = Random();

    for (List<Packet> listOfPackets in packetList) {
      if (idxIsRouter(packetList.indexOf(listOfPackets))) {
        for (int i = 0; i < random.nextInt(5); i++) {
          int packetTo = random.nextInt(3) + 1;
          int packetFrom = random.nextInt(3) + 1;
          listOfPackets.add(Packet(packetFrom, packetTo, playerNames, GlobalKey(), false, false));
        }
      }
    }

     WidgetsBinding.instance.addPostFrameCallback((_) {
      showVideo();
    });
  }

  late List<String> playerNames = [
    widget.player1Name,
    widget.player2Name,
    widget.player3Name
  ];

  List<GlobalKey> globalKeys =
      List<GlobalKey>.generate(7, (index) => GlobalKey());

  Future<void> showPopupWithTitleAndSubtitle(
      BuildContext context, String title, String subtitle) async {
    return await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(subtitle),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  void advance(BuildContext context) async {
    if (!victoryQuestion()) {
      if (phase != 1) {
        phase++;
      }
      else if (phase == 1) {
        if (widget.gameManager.playerInControl == 1) {
          if (packetList[1].isEmpty ||
              routersDisabled.contains(1) ||
              allPacketsAreLocked(1)) {
            if (!routersUsed.contains(1)) {
              routersUsed.add(1);
            }
          }
          if (packetList[2].isEmpty ||
              routersDisabled.contains(2) ||
              allPacketsAreLocked(2)) {
            if (!routersUsed.contains(2)) {
              routersUsed.add(2);
            }
          }
        }
        if (widget.gameManager.playerInControl == 2) {
          if (packetList[3].isEmpty ||
              routersDisabled.contains(3) ||
              allPacketsAreLocked(3)) {
            if (!routersUsed.contains(3)) {
              routersUsed.add(3);
            }
          }
          if (packetList[4].isEmpty ||
              routersDisabled.contains(4) ||
              allPacketsAreLocked(4)) {
            if (!routersUsed.contains(4)) {
              routersUsed.add(4);
            }
          }
        }
        if (widget.gameManager.playerInControl == 3) {
          if (packetList[6].isEmpty ||
              routersDisabled.contains(6) ||
              allPacketsAreLocked(6)) {
            if (!routersUsed.contains(6)) {
              routersUsed.add(6);
            }
          }
          if (packetList[8].isEmpty ||
              routersDisabled.contains(8) ||
              allPacketsAreLocked(8)) {
            if (!routersUsed.contains(8)) {
              routersUsed.add(8);
            }
          }
        }

        if (routersUsed.length >= 2) {
          phase++;
          routersUsed.clear();
        }
      }

      if (phase > 2) {

        phase = 0;

        widget.gameManager.playerInControl++;
        widget.gameManager.turn++;

        Random random = Random();
        setState(() {
          packetList[10].insert(1, Packet(5, 4, playerNames, GlobalKey(), true, false));
        });
        await toggleSelectionMode(packetList[10][0]);
        await confirmMovePacket(9, context, advanceTurn: false);
        if (widget.gameManager.playerInControl > 3) {
          if (!allPacketsAreDeliveredForPlayer(1)) {
            playerHappiness[0] -= 1;
          }
          if (!allPacketsAreDeliveredForPlayer(2)) {
            playerHappiness[1] -= 1;
          }
          if (!allPacketsAreDeliveredForPlayer(3)) {
            playerHappiness[2] -= 1;
          }

          if (playerHappiness[0] < 0) {
            playerHappiness[0] = 0;
          }

          if (playerHappiness[1] < 0) {
            playerHappiness[1] = 0;
          }

          if (playerHappiness[2] < 0) {
            playerHappiness[2] = 0;
          }

          if (playerHappiness[0] <= 0 ||
              playerHappiness[1] <= 0 ||
              playerHappiness[2] <= 0) {
            setState(() {
              showingDefeatOverlay = true;
            });
          }

          widget.gameManager.playerInControl = 1;

          if (packetList[9].isNotEmpty) {
            if (packetList[9][0].packetTo == 4) {
              if (packetList[9][0].isHandshakePacket) {
                setState(() {
                  packetList[9][0].packetTo = packetList[9][0].packetFrom;
                  packetList[9][0].packetFrom = 4;
                  packetList[9][0].isFileRequestPacket = false;
                  packetList[9][0].isHandshakePacket = true;
                });
              }
              if (packetList[9][0].isFileRequestPacket) {
                setState(() {
                  packetList[9][0].packetTo = packetList[9][0].packetFrom;
                  packetList[9][0].packetFrom = 4;
                  for(int j=0;j<2;j++) {
                    packetList[9].insert(j+1,Packet(packetList[9][0].packetFrom,packetList[9][0].packetTo,packetList[9][0].playerNames, GlobalKey(), false, true));
                  }
                });
              }
              if(!packetList[9][0].isFileRequestPacket && !packetList[9][0].isHandshakePacket)
              {
                setState(() {
                  packetList[9][0].packetTo = packetList[9][0].packetFrom;
                  packetList[9][0].packetFrom = 4;
                });
              }
            }
            List<int> routers=[1,4,6];
            if(packetList[9][0].packetTo==5 && packetList[9][0].isHandshakePacket)
            {
              await toggleSelectionMode(packetList[9][0]);
              await confirmMovePacket(10, context, advanceTurn: false);
            }
            else if(!packetList[9][0].isFileRequestPacket && packetList[9][0].isHandshakePacket)
            {
              await toggleSelectionMode(packetList[9][0]);
              await confirmMovePacket(routers[Random().nextInt(3)], context, advanceTurn: false);
            }
            else{
              for(int j=0;j<3;j++) {
                 int randomInt = random.nextInt(3);
                 int destination = 1;
                toggleSelectionMode(packetList[9][0]);
                await Future.delayed(const Duration(milliseconds: 700));
                await confirmMovePacket(routers[j], context, advanceTurn: false);
                //await Future.delayed(const Duration(milliseconds: 700));
              }
            }
          }
        }

        showingPassOverlay = true;

        roundStartPopupCompleter = Completer();

        playAudio("nextround.wav", .05);

        //RANDOM PACKETS
        /*
        for (List<Packet> listOfPackets in packetList) {
          if (!IDXIsRouter(packetList.indexOf(listOfPackets)) &&
              packetList.indexOf(listOfPackets) != 9) {
            if (random.nextBool()) {
              //Disable me for guaranteed packet spawn
              int packetTo =
                  getPlayerControllingObject(packetList.indexOf(listOfPackets));

              while (packetTo ==
                  getPlayerControllingObject(
                      packetList.indexOf(listOfPackets))) {
                packetTo = random.nextInt(3) + 1;
              }

              listOfPackets.add(Packet(
                  getPlayerControllingObject(packetList.indexOf(listOfPackets)),
                  packetTo,
                  playerNames,
                  GlobalKey(),
                  false));
            }
          }
        }
        */

        await roundStartPopupCompleter.future;

        if (widget.levelFourMode) {
          if (widget.gameManager.turn > 3) {
            if (routersDisabled.isEmpty) {
              if (false) {
                //random.nextBool()
                //Disable to always disable a router each turn
                int routerToDisable = -1;

                while (!idxIsRouter(routerToDisable) || routerToDisable == -1) {
                  routerToDisable = random.nextInt(9);
                }

                routersDisabled.add(routerToDisable);
                turnRouterDisabled = widget.gameManager.turn;

                await showPopupWithTitleAndSubtitle(context, "Router Disabled!",
                    "A router has been disabled! No packets can be moved to or from this router, and all packets inside it are trapped! The router will be back in 3 turns.");
              }
            }
          }
        }

        if (routersDisabled.isNotEmpty) {
          if (widget.gameManager.turn - turnRouterDisabled >= 3) {
            routersDisabled.clear();
            turnRouterDisabled = -1;
            await showPopupWithTitleAndSubtitle(context, "Router Repaired!",
                "The disabled router has been repaired, and is now available for use again!");
          }
        }
      }
    }

    if (!hasAnyPackets() && !victoryQuestion() && phase != 2) {
      if (phase == 0) {
        if (widget.gameManager.playerInControl == 1) {
          if (allPacketsAreLocked(0)) {
            await showPopupWithTitleAndSubtitle(
                context,
                "All Packets in Computer Locked",
                "All of the packets in your computer are locked, deliver your handshake packet first to unlock them!");
          } else {
            await showPopupWithTitleAndSubtitle(
                context,
                "No Packets In Computer",
                "You don't have any packets in your computer at the moment, so that phase of your turn has been automatically skipped.");
          } //0, 5, 7
        }
        else if (widget.gameManager.playerInControl == 2) {
          if (allPacketsAreLocked(5)) {
            await showPopupWithTitleAndSubtitle(
                context,
                "All Packets in Computer Locked",
                "All of the packets in your computer are locked, deliver your handshake packet first to unlock them!");
          } else {
            await showPopupWithTitleAndSubtitle(
                context,
                "No Packets In Computer",
                "You don't have any packets in your computer at the moment, so that phase of your turn has been automatically skipped.");
          }
        }
        else if (widget.gameManager.playerInControl == 3) {
          if (allPacketsAreLocked(7)) {
            await showPopupWithTitleAndSubtitle(
                context,
                "All Packets in Computer Locked",
                "All of the packets in your computer are locked, deliver your handshake packet first to unlock them!");
          } else {
            await showPopupWithTitleAndSubtitle(
                context,
                "No Packets In Computer",
                "You don't have any packets in your computer at the moment, so that phase of your turn has been automatically skipped.");
          }
        }
      } else if (phase == 1) {
        await showPopupWithTitleAndSubtitle(context, "No Packets In Router",
            "You don't have any packets in your router at the moment, so that phase of your turn has been automatically skipped.");
      }
      advance(context);
    }

    if (victoryQuestion()) {
      playAudio("VICTORY.wav", .25);

      setState(() {
        showingVictoryOverlay = true;
      });
    }
  }

  int getPlayerControllingObject(int objectIDX) {
    if (objectIDX < 3) {
      return 1;
    } else if (objectIDX < 6) {
      return 2;
    } else {
      return 3;
    }
  }

  bool allPacketsAreDeliveredForPlayer(int player) {
    List<Packet> completePacketList = [];

    for (var subList in packetList) {
      completePacketList.addAll(subList);
    }

    return !completePacketList.any((element) =>
        element.packetFrom == player || element.packetTo == player);
  }

  bool getIfInteractable(int position) {
    if (animationState >= 1) {
      return false;
    }

    switch (position) {
      case 0:
        if (selectionOriginPacket != null &&
            (destinationIsToDestination(0, selectionOriginPacket!.packetTo) ||
                destinationIsToDestination(
                    0, selectionOriginPacket!.packetFrom))) {
          return selectionMode == 2 || selectionMode == 4;
        } else {
          return false;
        }
      case 1:
        return selectionMode == 2 || selectionMode == 4 || selectionMode == 3;
      case 2:
        return selectionMode == 8 || selectionMode == 0 || selectionMode == 1;
      case 3:
        return selectionMode == 1 ||
            selectionMode == 4 ||
            selectionMode == 6 ||
            selectionMode == 8;
      case 4:
        return selectionMode == 3 ||
            selectionMode == 1 ||
            selectionMode == 5 ||
            selectionMode == 0;
      case 5:
        if (selectionOriginPacket != null &&
            (destinationIsToDestination(5, selectionOriginPacket!.packetTo) ||
                destinationIsToDestination(
                    5, selectionOriginPacket!.packetFrom))) {
          return selectionMode == 8 || selectionMode == 4;
        } else {
          return false;
        }
      case 6:
        return selectionMode == 3 || selectionMode == 8 || selectionMode == 7;
      case 7:
        if (selectionOriginPacket != null &&
            (destinationIsToDestination(7, selectionOriginPacket!.packetTo) ||
                destinationIsToDestination(
                    7, selectionOriginPacket!.packetFrom))) {
          return selectionMode == 6 || selectionMode == 8;
        } else {
          return false;
        }
      case 8:
        return selectionMode == 2 ||
            selectionMode == 5 ||
            selectionMode == 3 ||
            selectionMode == 6 ||
            selectionMode == 7;
      case 9:
        return selectionMode == 1 || selectionMode == 4 || selectionMode == 6;
      default:
        return false;
    }
  }

  bool destinationIsToDestination(int destination, int packetTo) {
    switch (destination) {
      case 0:
        return packetTo == 1;
      case 5:
        return packetTo == 2;
      case 7:
        return packetTo == 3;
      case 10:
        return packetTo == 5;
      default:
        return false;
    }
  }

  bool victoryQuestion() {
    return packetsDelivered >= 7;
  }

  Future<void> animatePacket(int origin, int destination) async {
    //print(origin);
    //print(destination);

    //print(animationOffsets);

    List<Offset> offsetsForCurrentAnimation;

    bool reversed = false;

    if (animationOffsets[EdgeForAnimation(origin, destination)] != null) {
      offsetsForCurrentAnimation = animationOffsets[EdgeForAnimation(origin, destination)]!;
    } else {
      offsetsForCurrentAnimation = animationOffsets[EdgeForAnimation(destination, origin)]!;
      reversed = true;
    }
    if (!reversed) {
      for (Offset currentOffset in offsetsForCurrentAnimation) {
        //left = dx, top = dy
        setState(() {
          animationLeft = currentOffset.dx - (animationWidth * .5);
          animationTop = currentOffset.dy - (animationHeight * .5);
        });

        await Future.delayed(const Duration(milliseconds: 650));
      }
    }
    else {
      for (Offset currentOffset in offsetsForCurrentAnimation.reversed) {
        //left = dx, top = dy
        setState(() {
          animationLeft = currentOffset.dx - (animationWidth * .5);
          animationTop = currentOffset.dy - (animationHeight * .5);
        });

        await Future.delayed(const Duration(milliseconds: 650));
      }
    }
  }

  Future<void> confirmMovePacket(int destination, BuildContext context, {bool advanceTurn = true}) async {
    int originIDX = -1;

    for (var element in packetList) {
      bool removed = element.remove(selectionOriginPacket);

      if (removed) {
        originIDX = packetList.indexOf(element);
      }
    }

    setState(() {
      animationState = 1;

      animationTo = selectionOriginPacket!.packetTo;
      animationFrom = selectionOriginPacket!.packetFrom;
      animationColor = selectionOriginPacket!.getPacketColor();
      animationIsHandshakePacket = selectionOriginPacket!.isHandshakePacket;
      animationIsFilePacket = selectionOriginPacket!.isFileRequestPacket;

      animationHeight = (selectionOriginPacket!.getKey().currentContext!.findRenderObject() as RenderBox).size.height;
      animationWidth = (selectionOriginPacket!.getKey().currentContext!.findRenderObject() as RenderBox).size.width;
    });

    await animatePacket(originIDX, destination);

    setState(() {
      RenderBox aniProp = placeholderGlobalKeys[destination].currentContext!.findRenderObject() as RenderBox;
      animationLeft = aniProp.localToGlobal(Offset.zero).dx;
      animationTop  = aniProp.localToGlobal(Offset.zero).dy;
    });

    await Future.delayed(const Duration(milliseconds: 650));

    /*if (destination == 9 && selectionOriginPacket!.packetTo == 4) {
      selectionOriginPacket!.packetTo = selectionOriginPacket!.packetFrom;
      selectionOriginPacket!.packetFrom = 4;
      selectionOriginPacket!.isPriorityPacket = true;

      setState(() {
        animationState = 1;

        animationBottomText = selectionOriginPacket!.getBottomText();
        animationTopText = selectionOriginPacket!.getTopText();
        animationColor = selectionOriginPacket!.getPacketColor();
        animationIsPriorityPacket = selectionOriginPacket!.isPriorityPacket;
      });

      await animatePacket(destination, originIDX);

      setState(() {
        animationLeft = (placeholderGlobalKeys[originIDX]
                .currentContext!
                .findRenderObject() as RenderBox)
            .localToGlobal(Offset.zero)
            .dx;

        animationTop = (placeholderGlobalKeys[originIDX]
                .currentContext!
                .findRenderObject() as RenderBox)
            .localToGlobal(Offset.zero)
            .dy;
      });

      await Future.delayed(Duration(milliseconds: 1000));

      packetList[originIDX].add(selectionOriginPacket!);

      if (IDXIsRouter(selectionMode)) {
        routersUsed.add(selectionMode);
      }

      toggleSelectionMode(null);

      animationState = -1;

      advance(context);
    } else {*/
    if (destinationIsToDestination(destination, selectionOriginPacket!.packetTo)) {
      setState(() {
        animationState = 2;
      });

      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      if (!destinationIsToDestination(destination, selectionOriginPacket!.packetTo))
      {
        packetList[destination].add(selectionOriginPacket!);
      }
      else {
        playAudio("packetDelivered.mp3", .05);
        if (allPacketsAreDeliveredForPlayer(selectionOriginPacket!.packetTo)) {
          playerHappiness[selectionOriginPacket!.packetTo-1] = 7;
        }
        if (selectionOriginPacket!.isFileRequestPacket) {
          packetsDelivered++;

          playerHappiness[selectionOriginPacket!.packetTo - 1] += 3;

          if (playerHappiness[selectionOriginPacket!.packetTo - 1] > 7) {
            playerHappiness[selectionOriginPacket!.packetTo - 1] = 7;
          }
        }
        if (selectionOriginPacket!.isHandshakePacket && selectionOriginPacket!.packetTo!=5) {
          showPopupWithTitleAndSubtitle(context, "Handshake Completed!",
              "You can now move and deliver file packets!");

          handshakesCompleted.add(selectionOriginPacket!.packetTo);

          playerHappiness[selectionOriginPacket!.packetTo - 1] += 2;

          if (playerHappiness[selectionOriginPacket!.packetTo - 1] > 7) {
            playerHappiness[selectionOriginPacket!.packetTo - 1] = 7;
          }
        }
      }

      if (idxIsRouter(selectionMode)) {
        routersUsed.add(selectionMode);
      }

      toggleSelectionMode(null);

      animationState = -1;

      if (advanceTurn) {
        advance(context);
      }
    });
    //}
  }

  bool idxIsRouter(int idx) {
    return idx == 1 || idx == 2 || idx == 3 || idx == 4 || idx == 6 || idx == 8;
  }

  Future<void> toggleSelectionMode(Packet? originPacket) async {
    setState(() {
      if (selectionMode == -1 && originPacket != selectionOriginPacket) {
        RenderBox obj = originPacket!.getKey().currentContext!.findRenderObject() as RenderBox;

        animationLeft = obj.localToGlobal(Offset.zero).dx;

        animationTop = obj.localToGlobal(Offset.zero).dy;

        animationHeight = obj.size.height;

        animationWidth = obj.size.width;

        animationState = 0;

        for (List<Packet> testPacket in packetList) {
          if (testPacket.contains(originPacket)) {
            selectionMode = packetList.indexOf(testPacket);
          }
        }

        selectionOriginPacket = originPacket;
      } else {
        selectionOriginPacket = null;
        selectionMode = -1;
      }
    });
  }

  int getNotServerToFrom(Packet packet) {
    if (packet.packetFrom == 4) {
      return packet.packetTo;
    } else {
      return packet.packetFrom;
    }
  }

  bool allPacketsAreLocked(int idx) {
    bool allPacketsLocked = true;

    if (packetList[idx].isEmpty) {
      return false;
    }
    for (Packet packet in packetList[idx]) {
      if (!packet.isFileRequestPacket || handshakesCompleted.contains(getNotServerToFrom(packet))) { // ! || handshakesCompleted.contains(getNotServerToFrom(packet))
        allPacketsLocked = false;
      }
    }

    return allPacketsLocked;
  }

  bool hasAnyPackets() {
    if (widget.gameManager.playerInControl == 1) {
      if (phase == 0) {
        return packetList[0].isNotEmpty && !allPacketsAreLocked(0);
      } else {
        return (packetList[1].isNotEmpty && !allPacketsAreLocked(1)) ||
            (packetList[2].isNotEmpty && !allPacketsAreLocked(2));
      }
    }
    else if (widget.gameManager.playerInControl == 2) {
      if (phase == 0) {
        return packetList[5].isNotEmpty && !allPacketsAreLocked(5);
      } else {
        return (packetList[3].isNotEmpty && !allPacketsAreLocked(3)) ||
            (packetList[4].isNotEmpty && !allPacketsAreLocked(4));
      }
    }
    else if (widget.gameManager.playerInControl == 3) {
      if (phase == 0) {
        return packetList[7].isNotEmpty && !allPacketsAreLocked(7);
      } else {
        return (packetList[6].isNotEmpty && !allPacketsAreLocked(6)) ||
            (packetList[8].isNotEmpty && !allPacketsAreLocked(8));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SizedBox.expand(
            child: Image(
              image: AssetImage("assets/background.jpg"),
              fit: BoxFit.cover,
            ),
          ),
          SizedBox.expand(
            child: Material(color: Colors.black.withOpacity(.65)),
          ),
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo on the left side
                        Image.asset(
                          'assets/logo.png',
                          height: 100, // Adjust the height as needed
                        ),

                        // Centered text
                        Expanded(
                          child: Center(
                            child: Text(
                              "Turn #${widget.gameManager.turn}: ${widget.getCurrentControllingPlayerName()}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize:
                                    MediaQuery.of(context).size.width * 0.013,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.only(bottom: 10)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () async {
                            showVideo();
                          },
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFf39c12)),
                            child: const Text(
                              'Rules of the Game',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Center(child: getTurnPhaseTextWidget()),
                        const SizedBox(width: 20),
                        InkWell(
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Tips to Success:',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600)),
                                    content: const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '1. You cannot move a packet through a computer that did not send or receive it.',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                            '2. Collaborate with your teammates to map the best paths for each color prior to starting game and each move.',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500)),
                                        Text(
                                            '3. When possible, pass packet from your computer to router within your region to maximize turn.',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500)),
                                         Text(
                                            '4. A handshake packet must be successfully transmitted between devices before any packets can be sent to the receiving device.',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500)),
                                          Text(
                                            '5. The attacker will also be sending request packets to the server, so don\'t get discouraged by the competition,\n'
                                            '    but rather work with your team to try to prevent them from flooding the network.', 
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                                ),
                                                ),        
                                      ],
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          textStyle: Theme.of(context)
                                              .textTheme
                                              .labelLarge,
                                        ),
                                        child: const Text('Close'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                });
                          },
                          child: Container(
                            width: 100,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFf39c12)),
                            child: const Text(
                              'Help!',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.only(bottom: 10)),
                    Expanded(
                        child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        getComputerAndRouterWidgetWithIDX(1),
                        const Padding(padding: EdgeInsets.only(left: 40)),
                        getComputerAndRouterWidgetWithIDX(2),
                        const Padding(padding: EdgeInsets.only(left: 10)),
                        getHackerWidget(),
                        const Padding(padding: EdgeInsets.only(left: 10)),
                        getComputerAndRouterWidgetWithIDX(3),
                      ],
                    )),
                    const Padding(padding: EdgeInsets.only(top: 10)),
                    getServerWidget(context),
                    const Padding(padding: EdgeInsets.only(top: 10)),
                    Row(mainAxisSize: MainAxisSize.max, children: [
                      Text(
                        "Files Delivered (${getPacketsDelivered()}/9): ",
                        style: TextStyle(
                            color: getCurrentHighlightColor(),
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                      Expanded(
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width*0.005),
                              child: TweenAnimationBuilder<double>(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.fastOutSlowIn,
                                  tween: Tween<double>(
                                    begin: 0,
                                    end: getPacketsDelivered().toDouble() /
                                        9.0,
                                  ),
                                  builder: (context, value, _) =>
                                      LinearProgressIndicator(
                                        minHeight: 25,
                                        value: value,
                                        color: getCurrentHighlightColor(),
                                      ))))
                    ]),
                    const Padding(padding: EdgeInsets.only(top: 10)),
                    Container(
                        decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                  blurStyle: BlurStyle.outer,
                                  color: phase == 2
                                      ? Colors.white
                                      : Colors.transparent,
                                  spreadRadius: 0,
                                  blurRadius: routerServerPulseAnimation.value)
                            ]),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: phase == 2
                                ? () {
                                    advance(context);
                                  }
                                : null,
                            child: const Text(
                              "End My Turn",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ))
                  ]))),
          getConnectionLines(),
          getArrows(),
          getPacketAnimationWidget(),
          getPassOverlayWidget(),
          getVictoryOverlayWidget(),
          getDefeatOverlayWidget()
        ],
      ),
    );
  }

  Widget getServerWidget(BuildContext context) {
    return Container(
        height: MediaQuery.of(context).size.height * .09,
        decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.rectangle,
            boxShadow: [
              BoxShadow(
                  blurStyle: BlurStyle.outer,
                  color:
                      getIfInteractable(9) ? Colors.white : Colors.transparent,
                  spreadRadius: 0,
                  blurRadius: routerServerPulseAnimation.value)
            ]),
        child: Material(
            key: computerAndRouterGlobalKeys[9],
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            shape: const RoundedRectangleBorder(
                side: BorderSide(width: 5, color: Colors.white)),
            child: InkWell(
              onTap: getIfInteractable(9)
                  ? () => confirmMovePacket(9, context)
                  : null,
              child: Stack(children: [
                Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(
                        Icons.dns,
                        size: MediaQuery.of(context).size.width*0.025,
                        color: Colors.white,
                      ),
                      const Text("IP: Server", style: TextStyle(color: Colors.white))
                    ])),
                GridView.count(
                    primary: false,
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width*0.0104),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    crossAxisCount: 1,
                    scrollDirection: Axis.horizontal,
                    children: packetList[9]
                            .map((e) => e.getPacketWidget(
                                context,
                                toggleSelectionMode,
                                false,
                                pulseAnimation.value,
                                selectionOriginPacket == e,
                                e.isFileRequestPacket &&
                                    !handshakesCompleted
                                        .contains(e.packetFrom)))
                            .toList() +
                        [
                          SizedBox.expand(
                            key: placeholderGlobalKeys[9],
                          )
                        ])
              ]),
            )));
  }

  Widget getConnectionLines() {
    return IgnorePointer(
        child: Stack(
      children: [
        getVerticalConnectionBetweenIDX(
            0, 2, selectionMode == 0 || selectionMode == 2),
        getLeftToBottomConnectionBetweenIDX(
            1, 2, selectionMode == 1 || selectionMode == 2),
        getTwoToEightConnectionBetweenIDX(
            2, 8, selectionMode == 8 || selectionMode == 2),  //Similar sample
        getHorizontalConnectionBetweenIDX(
            0, 4, selectionMode == 4 || selectionMode == 0),
        getLeftToBottomConnectionBetweenIDX(
            3, 1, selectionMode == 3 || selectionMode == 1),
        getHorizontalConnectionBetweenIDX(
            1, 4, selectionMode == 1 || selectionMode == 4),
        getRightToBottomConnectionBetweenIDX(
            3, 4, selectionMode == 3 || selectionMode == 4),
        getRightToTopConnectionBetweenIDX(
            5, 4, selectionMode == 5 || selectionMode == 4),
        getHorizontalConnectionBetweenIDX(
            5, 8, selectionMode == 5 || selectionMode == 8),
        getThreeToEightConnectionBetweenIDX(
            3, 8, selectionMode == 3 || selectionMode == 8),  //Similar sample
        getHorizontalConnectionBetweenIDX(
            3, 6, selectionMode == 3 || selectionMode == 6),
        getRightToBottomConnectionBetweenIDX(
            6, 7, selectionMode == 6 || selectionMode == 7),
        getRightToTopConnectionBetweenIDX(
            8, 7, selectionMode == 8 || selectionMode == 7),
        getVerticalConnectionBetweenIDX(
            6, 8, selectionMode == 6 || selectionMode == 8),
        getSpecialConnectionBetweenIDX(
             9, 1, selectionMode == 1 || selectionMode == 9),  //This is it.
        getHackerConnectionBetweenIDX(
            9, 10, selectionMode == 10 || selectionMode == 9),  //This is 2-it.
        getVerticalConnectionBetweenIDX(
            9, 4, selectionMode == 4 || selectionMode == 9),
        getVerticalConnectionBetweenIDX(
            9, 6, selectionMode == 6 || selectionMode == 9),
      ],
    ));
  }

  Widget getHackerConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      double distanceBetween = (computerAndRouterGlobalKeys[idx2]
          .currentContext!
          .findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero)
          .dx -
          ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject()
          as RenderBox)
              .localToGlobal(Offset.zero)
              .dx +
              ((computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .size
                  .width *
                  0.5));

      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .size
                      .width *
                      0.5),
              (computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx + (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox).size.width/2,
              (computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy -
                  ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width * .18)),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx + (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox).size.width/2,
              (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy +
                  ((computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .size
                      .height)),
        ]
      });

      return Stack(children: [
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          0.5),
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy),
              Offset(
                  (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx + (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox).size.width/2,
                  (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy -
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width * .18)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx + (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox).size.width/2,
                  (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy -
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width * .18)),
              Offset(
                  (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx + (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox).size.width/2,
                  (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                      ((computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox).size.height)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        )
      ]);
    } else {
      return Container();
    }
  }

  Widget getSpecialConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      double distanceBetween = (computerAndRouterGlobalKeys[idx2]
          .currentContext!
          .findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero)
          .dx -
          ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject()
          as RenderBox)
              .localToGlobal(Offset.zero)
              .dx +
              ((computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .size
                  .width *
                  0.5));

      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .size
                      .width *
                      0.5),
              (computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy),
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx +
                  ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                      0.5) +
                  (distanceBetween * .8),
              (computerAndRouterGlobalKeys[idx1]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy -
                  ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.height * .3)),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx + (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox).size.width/2,
              (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy +
                  ((computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .size
                      .height)),
        ]
      });

      return Stack(children: [
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          0.5),
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy),
              Offset(
                  (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          0.5) +
                      (distanceBetween * .8),
                  (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy -
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.height * .3)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          0.5) +
                      (distanceBetween * .8),
                  (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy -
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.height * .3)),
              Offset(
                  (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx + (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox).size.width/2,
                  (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                      ((computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox).size.height)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        )
      ]);
    } else {
      return Container();
    }
  }

  Widget getThreeToEightConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      double distanceBetween = (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox)
              .localToGlobal(Offset.zero)
              .dx -
          ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject()
                      as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx +
              ((computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .size
                      .width *
                  1));

      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1) +
                  (distanceBetween * .2),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .25)),
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1) +
                  (distanceBetween * .8),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .25)),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx,
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
        ]
      });

      return Stack(children: [
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          1),
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .height *
                          .5)),
              Offset(
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          1) +
                      (distanceBetween * .2),
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.height * .25)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          1) +
                      (distanceBetween * .2),
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .height *
                          .25)),
              Offset(
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          1) +
                      (distanceBetween * .8),
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.height * .25)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .width *
                          1) +
                      (distanceBetween * .8),
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject()
                              as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .height *
                          .25)),
              Offset(
                  (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx,
                  (computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox).size.height * .5)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        )
      ]);
    } else {
      return Container();
    }
  }

  Widget getTwoToEightConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      double distanceBetween = (computerAndRouterGlobalKeys[idx2]
                  .currentContext!
                  .findRenderObject() as RenderBox)
              .localToGlobal(Offset.zero)
              .dx -
          ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject()
                      as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx +
              ((computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .size
                      .width *
                  1));

      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1) +
                  (distanceBetween * .2),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy -
                  2.5),
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1) +
                  (distanceBetween * .8),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy -
                  2.5),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx,
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
        ]
      });

      return Stack(children: [
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                          1),
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .height *
                          .5)),
              Offset(
                  (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .width *
                          1) +
                      (distanceBetween * .2),
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy -
                      2.5),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .width *
                          1) +
                      (distanceBetween * .2),
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy -
                      2.5),
              Offset(
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .width *
                          1) +
                      (distanceBetween * .8),
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy -
                      2.5),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        ),
        CustomPaint(
          size: Size.infinite,
          painter: LinesPainter(
              Offset(
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dx +
                      ((computerAndRouterGlobalKeys[idx1]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .width *
                          1) +
                      (distanceBetween * .8),
                  (computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy -
                      2.5),
              Offset(
                  (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx,
                  (computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .localToGlobal(Offset.zero)
                          .dy +
                      ((computerAndRouterGlobalKeys[idx2]
                                  .currentContext!
                                  .findRenderObject() as RenderBox)
                              .size
                              .height *
                          .5)),
              enabled ? getCurrentHighlightColor() : Colors.grey),
        )
      ]);
    } else {
      return Container();
    }
  }

  Widget getHorizontalConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx,
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5))
        ]
      });
      return CustomPaint(
        size: Size.infinite,
        painter: LinesPainter(
            Offset(
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx1]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .width *
                        1),
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject()
                            as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    ((computerAndRouterGlobalKeys[idx1]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .height *
                        .5)),
            Offset(
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject()
                        as RenderBox)
                    .localToGlobal(Offset.zero)
                    .dx,
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject()
                            as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    ((computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox).size.height * .5)),
            enabled ? getCurrentHighlightColor() : Colors.grey),
      );
    } else {
      return Container();
    }
  }

  Widget getLeftToBottomConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dx,
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      .5),
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .size
                      .height)
        ]
      });

      return CustomPaint(
        size: Size.infinite,
        painter: LinesPainter(
            Offset(
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                    .localToGlobal(Offset.zero)
                    .dx,
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    ((computerAndRouterGlobalKeys[idx1]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .height *
                        .5)),
            Offset(
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject()
                            as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx2]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .width *
                        .5),
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject()
                            as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    (computerAndRouterGlobalKeys[idx2]
                            .currentContext!
                            .findRenderObject() as RenderBox)
                        .size
                        .height),
            enabled ? getCurrentHighlightColor() : Colors.grey),
      );
    } else {
      return Container();
    }
  }

  Widget getRightToBottomConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      .5),
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .size
                      .height)
        ]
      });

      return CustomPaint(
        size: Size.infinite,
        painter: LinesPainter(
            Offset(
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox).size.width *
                        1),
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    ((computerAndRouterGlobalKeys[idx1]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .height *
                        .5)),
            Offset(
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox).size.width *
                        .5),
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    (computerAndRouterGlobalKeys[idx2]
                            .currentContext!
                            .findRenderObject() as RenderBox)
                        .size
                        .height),
            enabled ? getCurrentHighlightColor() : Colors.grey),
      );
    } else {
      return Container();
    }
  }

  Widget getRightToTopConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      //animationOffsets.addAll({EdgeForAnimation(idx1, idx2): []});
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      1),
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .height *
                      .5)),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      .5),
              (computerAndRouterGlobalKeys[idx2]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy)
        ]
      });

      return CustomPaint(
        size: Size.infinite,
        painter: LinesPainter(
            Offset(
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx1]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .width *
                        1),
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    ((computerAndRouterGlobalKeys[idx1]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .height *
                        .5)),
            Offset(
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx2]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .width *
                        .5),
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject() as RenderBox)
                    .localToGlobal(Offset.zero)
                    .dy),
            enabled ? getCurrentHighlightColor() : Colors.grey),
      );
    } else {
      return Container();
    }
  }

  Widget getVerticalConnectionBetweenIDX(int idx1, int idx2, bool enabled) {
    if (computerAndRouterGlobalKeys[idx1].currentContext != null &&
        computerAndRouterGlobalKeys[idx2].currentContext != null &&
        !routersDisabled.contains(idx1) &&
        !routersDisabled.contains(idx2)) {
      animationOffsets.addAll({
        EdgeForAnimation(idx1, idx2): [
          Offset(
              (computerAndRouterGlobalKeys[idx1]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx1]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      .5),
              (computerAndRouterGlobalKeys[idx1]
                      .currentContext!
                      .findRenderObject() as RenderBox)
                  .localToGlobal(Offset.zero)
                  .dy),
          Offset(
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dx +
                  ((computerAndRouterGlobalKeys[idx2]
                              .currentContext!
                              .findRenderObject() as RenderBox)
                          .size
                          .width *
                      .5),
              (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .localToGlobal(Offset.zero)
                      .dy +
                  (computerAndRouterGlobalKeys[idx2]
                          .currentContext!
                          .findRenderObject() as RenderBox)
                      .size
                      .height)
        ]
      });

      return CustomPaint(
        size: Size.infinite,
        painter: LinesPainter(
            Offset(
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx1]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .width *
                        .5),
                (computerAndRouterGlobalKeys[idx1].currentContext!.findRenderObject() as RenderBox)
                    .localToGlobal(Offset.zero)
                    .dy),
            Offset(
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject()
                            as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dx +
                    ((computerAndRouterGlobalKeys[idx2]
                                .currentContext!
                                .findRenderObject() as RenderBox)
                            .size
                            .width *
                        .5),
                (computerAndRouterGlobalKeys[idx2].currentContext!.findRenderObject()
                            as RenderBox)
                        .localToGlobal(Offset.zero)
                        .dy +
                    (computerAndRouterGlobalKeys[idx2]
                            .currentContext!
                            .findRenderObject() as RenderBox)
                        .size
                        .height),
            enabled ? getCurrentHighlightColor() : Colors.grey),
      );
    } else {
      return Container();
    }
  }

  Widget getArrows() {
    return const Stack(
      children: [],
    );
  }

  Color getIconColor(int packetFrom) {
    switch (packetFrom) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.white;
      case 5:
        return const Color(0xFFFFAE42);
      default:
        return Colors.grey;
    }
  }

  Widget getPacketAnimationWidget() {
    return animationState > -1
        ? AnimatedPositioned(
            left: animationLeft,
            top: animationTop,
            width: animationWidth,
            height: animationHeight,
            duration: const Duration(milliseconds: 650),
            child: animationState > 0
                ? IgnorePointer(
                    child: AnimatedSwitcher(
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                              scale: animation, child: child);
                        },
                        duration: const Duration(milliseconds: 500),
                        child: animationState < 2
                            ? SizedBox(
                                width: animationWidth,
                                height: animationHeight,
                                child: Material(
                                    clipBehavior: Clip.antiAlias,
                                    color: animationState > 0
                                        ? animationColor
                                        : Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(MediaQuery.of(context).size.width*0.0052)),
                                    child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          animationIsHandshakePacket
                                              ? Icon(
                                                  Icons.handshake,
                                                  color: getIconColor(animationFrom),
                                                  shadows: const [
                                                    Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 15.0)
                                                  ],
                                                )
                                              : Container(),
                                          animationIsFilePacket
                                              ? animationTo == 4
                                                  ? Icon(
                                                      Icons.download,
                                                      color: getIconColor(animationFrom),
                                                      shadows: const [
                                                        Shadow(
                                                            color: Colors.black,
                                                            blurRadius: 15.0)
                                                      ],
                                                    )
                                                  : Icon(
                                                      Icons.folder,
                                                      color: getIconColor(animationFrom),
                                                      shadows: const [
                                                        Shadow(
                                                            color: Colors.black,
                                                            blurRadius: 15.0)
                                                      ],
                                                    )
                                              : Container()
                                        ])))
                            : Container()))
                : Container())
        : Container();
  }

  int getPacketsDelivered() {
    return packetsDelivered;
  }

  Color getCurrentHighlightColor() {
    switch (widget.gameManager.playerInControl) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 5:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Widget getTurnPhaseTextWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedDefaultTextStyle(
            style: TextStyle(
                color: phase == 0 ? getCurrentHighlightColor() : Colors.grey,
                fontWeight: phase == 0 ? FontWeight.bold : FontWeight.normal,
                fontSize: phase == 0 ? 30 : 25),
            duration: const Duration(milliseconds: 250),
            child: const Text(
              "Move a packet from your Computer",
            )),
        const Padding(padding: EdgeInsets.only(left: 10)),
        const Text(
          ">",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.normal, fontSize: 30),
        ),
        const Padding(padding: EdgeInsets.only(left: 10)),
        AnimatedDefaultTextStyle(
            style: TextStyle(
                color: phase == 1 ? getCurrentHighlightColor() : Colors.grey,
                fontWeight: phase == 1 ? FontWeight.bold : FontWeight.normal,
                fontSize: phase == 1 ? 30 : 25),
            duration: const Duration(milliseconds: 250),
            child: const Text(
              "Move a packet from each Router",
            )),
        const Padding(padding: EdgeInsets.only(left: 10)),
        const Text(
          ">",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.normal, fontSize: 30),
        ),
        const Padding(padding: EdgeInsets.only(left: 10)),
        AnimatedDefaultTextStyle(
            style: TextStyle(
                color: phase == 2 ? getCurrentHighlightColor() : Colors.grey,
                fontWeight: phase == 2 ? FontWeight.bold : FontWeight.normal,
                fontSize: phase == 2 ? 30 : 25),
            duration: const Duration(milliseconds: 250),
            child: const Text(
              "End of Turn",
            )),
      ],
    );
  }

  Widget getPassOverlayWidget() {
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: showingPassOverlay
            ? Stack(
                key: const Key("stack"),
                children: [
                  SizedBox.expand(
                    child: Material(color: Colors.black.withOpacity(.65)),
                  ),
                  Center(
                      child: Card(
                    child: SizedBox(
                        width: 400,
                        height: 400,
                        child: Stack(children: [
                          Center(
                              child: Text(
                            "Turn ${widget.gameManager.turn}\nPass the computer to ${widget.getCurrentControllingPlayerName()}!",
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          )),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                                padding: EdgeInsets.all(MediaQuery.of(context).size.width*0.0052),
                                child: SizedBox(
                                  width: 400,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        showingPassOverlay = false;
                                        roundStartPopupCompleter.complete();
                                      });
                                    },
                                    child: Text("I'm ${widget
                                            .getCurrentControllingPlayerName()}!"),
                                  ),
                                )),
                          )
                        ])),
                  ))
                ],
              )
            : Container(
                key: const Key("container"),
              ));
  }

  Widget getDefeatOverlayWidget() {
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: showingDefeatOverlay
            ? Stack(
          key: const Key("Stack"),
          children: [
            SizedBox.expand(
              child: Material(color: Colors.black.withOpacity(.65)),
            ),
            Center(
                child: Card(
                  color: Colors.red,
                  child: SizedBox(
                      width: 400,
                      height: 400,
                      child: Stack(children: [
                        const Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Defeat!",
                                    style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    "One of your users took too long to recieve a file and became unhappy!",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ])),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                              padding: EdgeInsets.all(MediaQuery.of(context).size.width*0.0052),
                              child: SizedBox(
                                width: 400,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                            const PlayerCreationScreen()));
                                  },
                                  child: const Text(
                                    "New Game!",
                                  ),
                                ),
                              )),
                        )
                      ])),
                ))
          ],
        )
            : Container(
          key: const Key("container"),
        ));
  }

  Widget getVictoryOverlayWidget() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: showingVictoryOverlay
        ? Stack(
            key: const Key("Stack"),
            children: [
              SizedBox.expand(
                child: Material(color: Colors.black.withOpacity(.65)),
              ),
              Center(
                child: Card(
                color: Colors.green,
                child: SizedBox(
                    width: 400,
                    height: 400,
                    child: Stack(children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Victory!",
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              "It took you ${widget.gameManager.turn} turns to deliver all file request packets!",
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                        ])),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width*0.0052),
                          child: SizedBox(
                            width: 400,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const PlayerCreationScreen()));
                              },
                              child: const Text(
                                "New Game!",
                              ),
                            ),
                          )),
                      )
                    ])),
              ))
            ],
          )
        : Container(
              key: const Key("container"),
          ));
  }

  Widget getHackerWidget(){
    return Column(
        children: [
          Container(
              alignment: Alignment.center,
              width: MediaQuery.of(context).size.width*0.05,
              height: MediaQuery.of(context).size.width*0.05,
              decoration: BoxDecoration(
                border: Border.all(
                    width: MediaQuery.of(context).size.width * 0.002,
                    color: Colors.transparent),
                borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width*0.008),
              ),
              child:Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.fromSize(size: Size(MediaQuery.of(context).size.width*0.028,MediaQuery.of(context).size.width*0.028),child: packetList[10][0].getPacketWidget(
                        context,
                        toggleSelectionMode,
                        false,
                        pulseAnimation.value,
                        selectionOriginPacket == packetList[10][0],
                        packetList[10][0].isFileRequestPacket && !handshakesCompleted.contains(packetList[10][0].packetFrom))),
                    SizedBox.expand(child:Material(
                        key: computerAndRouterGlobalKeys[10],
                        clipBehavior: Clip.antiAlias,
                        color: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width*0.004)),
                        child:
                        Padding(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width*0.0052),
                          key: placeholderGlobalKeys[10],
                        )
                    )),
                    Icon(
                      Icons.computer,
                      size: MediaQuery.of(context).size.width*0.026,
                      color: const Color(0xFFFFAE42),
                    ),
                  ]
              ),
          ),
          Expanded(child: Container())
        ]
    );
  }
  Widget getComputerAndRouterWidgetWithIDX(int idx) {
    List<Widget> contents = [];

    if (idx == 1) {
      contents.add(Column(
        children: [
          getRouterWidget(2, idx),
          Expanded(child: Container()),
          getComputerWidget(0, idx)
        ],
      ));
      contents.add(Column(
        children: [
          Expanded(child: Container()),
          getRouterWidget(1, idx),
          Expanded(child: Container()),
        ],
      ));
    }
    if (idx == 2) {
      contents.add(Column(
        children: [
          getComputerWidget(5, idx),
          Expanded(child: Container()),
          getRouterWidget(3, idx),
        ],
      ));
      contents.add(Column(
        children: [
          Expanded(child: Container()),
          getRouterWidget(4, idx),
          Expanded(child: Container()),
        ],
      ));
    }
    if (idx == 3) {
      contents.add(Column(
        children: [
          getRouterWidget(8, idx),
          Expanded(child: Container()),
          getRouterWidget(6, idx),
        ],
      ));
      contents.add(Column(
        children: [
          Expanded(child: Container()),
          getComputerWidget(7, idx),
          Expanded(child: Container()),
        ],
      ));
    }
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(
            "${playerNames[idx - 1]} Happiness:",
            style: TextStyle(
                color: widget.gameManager.playerInControl == idx
                    ? getCurrentHighlightColor()
                    : Colors.grey,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 10),
          ),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      tween: Tween<double>(
                        begin: 0,
                        end: playerHappiness[idx - 1] / 7.0,
                      ),
                      builder: (context, value, _) =>
                          LinearProgressIndicator(
                            minHeight: 25,
                            value: value,
                            backgroundColor: Colors.transparent,
                            color: widget.gameManager.playerInControl == idx
                                ? getCurrentHighlightColor()
                                : Colors.grey,
                          ))))
        ]),
        const Padding(padding: EdgeInsets.only(top: 10)),
        Expanded(
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: widget.gameManager.playerInControl == idx
                      ? getCurrentHighlightColor()
                      : Colors.grey,
                  width: 5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: Row(children: contents)),
          )
        )
      ]),
    );
  }
  Color getPlayerColor(int playerIDX) {
    switch (playerIDX) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.white;
      case 5:
        return Colors.indigo;
      default:
        return Colors.blue;
    }
  }

  Widget getComputerWidget(int idx, int playerIDX) {
    String ip = "";

    switch (playerIDX) {
      case 1:
        ip = playerNames[0];
        break;
      case 2:
        ip = playerNames[1];
        break;
      case 3:
        ip = playerNames[2];
        break;
      default:
        break;
    }

    return Expanded(
        child: AspectRatio(
            aspectRatio: 1,
            child: Container(
                decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.rectangle,
                    boxShadow: [
                      BoxShadow(
                          blurStyle: BlurStyle.outer,
                          color: getIfInteractable(idx)
                              ? Colors.white
                              : Colors.transparent,
                          spreadRadius: 0,
                          blurRadius: routerServerPulseAnimation.value)
                    ]),
                child: Material(
                    key: computerAndRouterGlobalKeys[idx],
                    clipBehavior: Clip.antiAlias,
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        side: BorderSide(
                            width: 5, color: getPlayerColor(playerIDX))),
                    child: InkWell(
                      onTap: getIfInteractable(idx)
                          ? () => confirmMovePacket(idx, context)
                          : null,
                      child: Stack(children: [
                        Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              Icon(
                                Icons.computer,
                                size: 48,
                                color: getPlayerColor(playerIDX),
                              ),
                              Text("Name: $ip",
                                  style: TextStyle(
                                      color: getPlayerColor(playerIDX)))
                            ])),
                        GridView.count(
                            primary: false,
                            padding: EdgeInsets.all(MediaQuery.of(context).size.width*0.01),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            crossAxisCount: 2,
                            children: packetList[idx]
                                    .map((e) => e.getPacketWidget(
                                        context,
                                        toggleSelectionMode,
                                        (phase == 0 &&
                                                widget.gameManager
                                                        .playerInControl ==
                                                    playerIDX &&
                                                selectionMode == -1 &&
                                                animationState < 1 &&
                                                !routersUsed.contains(idx)) ||
                                            selectionOriginPacket == e,
                                        pulseAnimation.value,
                                        selectionOriginPacket == e,
                                        e.isFileRequestPacket &&
                                            !handshakesCompleted
                                                .contains(e.packetFrom)))
                                    .toList() +
                                [
                                  SizedBox.expand(
                                    key: placeholderGlobalKeys[idx],
                                  )
                                ])
                      ]),
                    )))));
  }

  Widget getRouterWidget(int idx, int playerIDX) {
    return Expanded(
        child: AspectRatio(
            aspectRatio: 1,
            child: !routersDisabled.contains(idx)
                ? Container(
                    decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              blurStyle: BlurStyle.outer,
                              color: getIfInteractable(idx)
                                  ? Colors.white
                                  : Colors.transparent,
                              spreadRadius: 0,
                              blurRadius: routerServerPulseAnimation.value)
                        ]),
                    child: Material(
                        key: computerAndRouterGlobalKeys[idx],
                        clipBehavior: Clip.antiAlias,
                        color: Colors.transparent,
                        shape: const CircleBorder(
                            side: BorderSide(width: 5, color: Colors.grey)),
                        child: InkWell(
                            onTap: getIfInteractable(idx)
                                ? () => confirmMovePacket(idx, context)
                                : null,
                            child: Stack(children: [
                              const Center(
                                  child: Icon(
                                Icons.router,
                                size: 48,
                                color: Colors.grey,
                              )),
                              GridView.count(
                                  primary: false,
                                  padding: EdgeInsets.all(MediaQuery.of(context).size.width*0.0104),
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  crossAxisCount: 2,
                                  children: packetList[idx]
                                          .map((e) => e.getPacketWidget(
                                              context,
                                              toggleSelectionMode,
                                              (phase == 1 &&
                                                      widget.gameManager
                                                              .playerInControl ==
                                                          playerIDX &&
                                                      selectionMode == -1 &&
                                                      animationState < 1 &&
                                                      packetList[idx]
                                                              .indexOf(e) ==
                                                          0 &&
                                                      !routersUsed
                                                          .contains(idx)) ||
                                                  selectionOriginPacket == e,
                                              pulseAnimation.value,
                                              selectionOriginPacket == e,
                                              e.isFileRequestPacket &&
                                                  !handshakesCompleted
                                                      .contains(e.packetFrom)))
                                          .toList() +
                                      [
                                        SizedBox.expand(
                                          key: placeholderGlobalKeys[idx],
                                        )
                                      ])
                            ]))))
                : Container()));
  }
}

class Packet {
  int packetFrom;
  int packetTo;
  List<String> playerNames;
  GlobalKey key; //GlobalKey key
  bool isHandshakePacket;
  bool isFileRequestPacket;

  Packet(this.packetFrom, this.packetTo, this.playerNames, this.key,
      this.isHandshakePacket, this.isFileRequestPacket);

  String getTopText() {
    if (packetTo != 4) {
      return "To: ${playerNames[packetTo - 1]}";
    }
    return "To: Server";
  }

  String getBottomText() {
    if (packetFrom != 4) {
      return "From: ${playerNames[packetFrom - 1]}";
    }
    return "From: Server";
  }

  Color getPacketColor() {
    switch (packetTo) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.white;
      case 5:
        return const Color(0xFFFFAE42);
      default:
        return Colors.grey;
    }
  }

  Color getIconColor() {
    switch (packetFrom) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.black;
      case 5:
        return const Color(0xFFFFAE42);
      default:
        return Colors.grey;
    }
  }


  GlobalKey getKey() {
    //Key
    return key;
  }

  Widget getPacketWidget(BuildContext context, Function switchToSelectMode, bool interactable,
      double animValue, bool amISelected, bool isLocked) {
    return SizedBox.expand(
      key: key,
      child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                  width: amISelected || isLocked ? MediaQuery.of(context).size.width * 0.002 : 0,
                  color: amISelected || isLocked
                      ? Colors.grey
                      : Colors.transparent),
              borderRadius:
                  amISelected || isLocked ? BorderRadius.circular(MediaQuery.of(context).size.width*0.008) : null,
              boxShadow: [
                BoxShadow(
                    color: interactable && !amISelected && !isLocked
                        ? Colors.white
                        : Colors.transparent,
                    blurRadius: animValue,
                    spreadRadius: animValue)
              ]),
          child: Material(
            clipBehavior: Clip.antiAlias,
            color: getPacketColor(),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width*0.004)),
            child: InkWell(
                onTap: interactable && !isLocked
                    ? () {
                        switchToSelectMode(this);
                      }
                    : null,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      !isLocked
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                  isHandshakePacket
                                      ? Icon(
                                          size: MediaQuery.of(context).size.width*0.0125,
                                          Icons.handshake,
                                          color: getIconColor(),
                                          shadows: const [
                                            Shadow(
                                                color: Colors.black,
                                                blurRadius: 15.0)
                                          ],
                                        )
                                      : Container(),
                                  isFileRequestPacket
                                      ? packetTo == 4
                                          ? Icon(
                                              size: MediaQuery.of(context).size.width*0.0125,
                                              Icons.download,
                                              color: getIconColor(),
                                              shadows: const [
                                                Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 15.0)
                                              ],
                                            )
                                          : Icon(
                                    size: MediaQuery.of(context).size.width*0.0125,
                                              Icons.folder,
                                              color: getIconColor(),
                                              shadows: const [
                                                Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 15.0)
                                              ],
                                            )
                                      : Container()
                                ])
                          : Icon(
                              size: MediaQuery.of(context).size.width*0.0125,
                              Icons.lock,
                              color: Colors.grey,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 15.0)
                              ],
                            )
                    ])),
          )),
    );
  }
}

class LinesPainter extends CustomPainter {
  final Offset start, end;
  Color lineColor;

  LinesPainter(this.start, this.end, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = lineColor
      ..strokeWidth = 4;

    final Path path = Path();
    path.moveTo(start.dx, start.dy);
    path.lineTo(end.dx, end.dy);

    const DashPainter(span: 4, step: 9).paint(canvas, path, paint);
  }

  @override
  bool shouldRepaint(LinesPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}
