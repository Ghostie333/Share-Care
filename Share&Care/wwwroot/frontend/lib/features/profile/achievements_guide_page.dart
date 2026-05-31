import 'package:flutter/material.dart';

import 'profile_trophies.dart';

class AchievementsGuidePage extends StatelessWidget {
  final ProfileAchievementStats stats;

  const AchievementsGuidePage({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievements = buildAchievementProgress(stats);

    return Scaffold(
      appBar: 
        AppBar(
          title: const Text('Trofea i osiągnięcia'),
          flexibleSpace: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dziękuję że jesteś'),
                ),
              );
            },
            child: Image.asset(
              'images/logo/shareandcare_logo.png',
              height: 40,
              ),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: achievements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        achievement.unlocked
                            ? Icons.emoji_events
                            : Icons.emoji_events_outlined,
                        color: achievement.unlocked
                            ? Colors.amber
                            : theme.iconTheme.color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              achievement.definition.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              achievement.definition.description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${achievement.current}/${achievement.definition.threshold}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: achievement.progress),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cel: ${achievement.definition.shortGoal}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
