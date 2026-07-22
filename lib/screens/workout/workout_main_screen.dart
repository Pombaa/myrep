import 'package:flutter/material.dart';

import 'workout_plan_tab.dart';
import 'workout_trainer_tab.dart';

class WorkoutMainScreen extends StatefulWidget {
  const WorkoutMainScreen({super.key});

  @override
  State<WorkoutMainScreen> createState() => _WorkoutMainScreenState();
}

class _WorkoutMainScreenState extends State<WorkoutMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.fitness_center),
              text: 'Treino',
            ),
            Tab(
              icon: Icon(Icons.psychology),
              text: 'Treinador IA',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          WorkoutPlanTab(onOpenTrainer: () => _tabController.animateTo(1)),
          const WorkoutTrainerTab(),
        ],
      ),
    );
  }
}
