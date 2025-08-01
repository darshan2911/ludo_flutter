import 'package:flutter/material.dart';
import 'package:ludo_flame/main.dart';
import 'package:ludo_flame/state/bot_controller.dart';

class BotDifficultyScreen extends StatefulWidget {
  const BotDifficultyScreen({super.key});

  @override
  BotDifficultyScreenState createState() => BotDifficultyScreenState();
}

class BotDifficultyScreenState extends State<BotDifficultyScreen> {
  BotDifficulty selectedDifficulty = BotDifficulty.medium;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff002fa7), Color(0xff002fa7)],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Select Bot Difficulty',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),

                // Easy Difficulty
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedDifficulty == BotDifficulty.easy
                          ? Colors.green
                          : Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedDifficulty = BotDifficulty.easy;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sentiment_satisfied,
                          color: selectedDifficulty == BotDifficulty.easy
                              ? Colors.white
                              : Colors.green,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Easy - Beginner Friendly',
                          style: TextStyle(
                            color: selectedDifficulty == BotDifficulty.easy
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Medium Difficulty
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          selectedDifficulty == BotDifficulty.medium
                          ? Colors.orange
                          : Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedDifficulty = BotDifficulty.medium;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sentiment_neutral,
                          color: selectedDifficulty == BotDifficulty.medium
                              ? Colors.white
                              : Colors.orange,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Medium - Balanced Challenge',
                          style: TextStyle(
                            color: selectedDifficulty == BotDifficulty.medium
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Hard Difficulty
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedDifficulty == BotDifficulty.hard
                          ? Colors.red
                          : Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      setState(() {
                        selectedDifficulty = BotDifficulty.hard;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sentiment_very_dissatisfied,
                          color: selectedDifficulty == BotDifficulty.hard
                              ? Colors.white
                              : Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Hard - Expert Level',
                          style: TextStyle(
                            color: selectedDifficulty == BotDifficulty.hard
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Start Game Button
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      // Set bot difficulty
                      BotController.instance.setBotDifficulty(
                        selectedDifficulty,
                      );

                      // Start VS Computer game
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GameApp(
                            selectedTeams: ['BP', 'GP'], // Human vs Bot
                            isVsComputer: true,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.black),
                        SizedBox(width: 10),
                        Text(
                          'Start Game',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Back Button
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Back',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
