import 'package:flutter/material.dart';
import 'package:levelthree/game.dart';

void main() {
  runApp(const LevelOneGame());
}

class LevelOneGame extends StatelessWidget {
  const LevelOneGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Level FIVE',
        theme: ThemeData(
          useMaterial3: true,
          primarySwatch: Colors.blue,
        ),
        home: const PlayerCreationScreen());
  }
}

class PlayerCreationScreen extends StatefulWidget {
  const PlayerCreationScreen({super.key});

  @override
  State<StatefulWidget> createState() => PlayerCreationScreenState();
}

class PlayerCreationScreenState extends State<PlayerCreationScreen> {
  String player1Name = "";
  String player2Name = "";
  String player3Name = "";

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
          Center(
            child: Card(
                child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 20),
                Image.asset(
                  'assets/logo1.png',
                  height: 100, // Adjust the height as needed
                ),
                const SizedBox(height: 5),
                const Text(
                  "CyberSim - Level 5",
                  style: TextStyle(
                    fontSize: 32, // Adjust font size as needed
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF595959),
                    fontFamily: 'RobotoSlab' // Make the text bold
                  ),
                ),
                const SizedBox(
                    height:
                        20),
                SizedBox(
                  width: 400,
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        player1Name = value;
                      });
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        label: Text("Name of Player 1")),
                  ),
                ), 
                
                const Padding(padding: EdgeInsets.only(top: 10)),
                SizedBox(
                  width: 400,
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        player2Name = value;
                      });
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        label: Text("Name of Player 2")),
                  ),
                ),
                const Padding(padding: EdgeInsets.only(top: 10)),
                SizedBox(
                  width: 400,
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        player3Name = value;
                      });
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        label: Text("Name of Player 3")),
                  ),
                ),
                const Padding(padding: EdgeInsets.only(top: 10)),
                SizedBox(
                    height: 50,
                    width: 400,
                    child: ElevatedButton(
                        onPressed: player1Name != "" &&
                                player2Name != "" &&
                                player3Name != ""
                            ? () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => Game(player1Name,
                                            player2Name, player3Name, true)));
                              }
                            : null,
                        child: const Text("Play Level 5!")))
              ]),
            )),
          )
        ],
      ),
    );
  }
}
