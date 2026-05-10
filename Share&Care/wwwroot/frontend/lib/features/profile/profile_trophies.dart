class ProfileAchievementStats {
  final int offersCreated;
  final int negotiationsCompleted;
  final int giveOffersCreated;
  final int firstDayPurchases;
  final int priceDrops;
  final int differentCities;

  const ProfileAchievementStats({
    required this.offersCreated,
    required this.negotiationsCompleted,
    required this.giveOffersCreated,
    required this.firstDayPurchases,
    required this.priceDrops,
    required this.differentCities,
  });
}

enum AchievementMetric {
  offersCreated,
  negotiationsCompleted,
  giveOffersCreated,
  firstDayPurchases,
  priceDrops,
  differentCities,
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final int threshold;
  final AchievementMetric metric;
  final String shortGoal;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.threshold,
    required this.metric,
    required this.shortGoal,
  });
}

class AchievementProgress {
  final AchievementDefinition definition;
  final int current;

  const AchievementProgress({
    required this.definition,
    required this.current,
  });

  bool get unlocked => current >= definition.threshold;
  double get progress => definition.threshold <= 0
      ? 1
      : (current / definition.threshold).clamp(0, 1);
}

const List<AchievementDefinition> profileAchievementDefinitions = <AchievementDefinition>[
  AchievementDefinition(
    id: 'negotiator',
    title: 'Negocjator',
    description: 'Wynegocjuj 10 ofert.',
    threshold: 10,
    metric: AchievementMetric.negotiationsCompleted,
    shortGoal: '10 zakończonych negocjacji',
  ),
  AchievementDefinition(
    id: 'giver',
    title: 'Darczyńca',
    description: 'Oddaj 10 rzeczy.',
    threshold: 10,
    metric: AchievementMetric.giveOffersCreated,
    shortGoal: '10 ofert oddania',
  ),
  AchievementDefinition(
    id: 'bargainHunter',
    title: 'Łapacz okazji',
    description: 'Kup 10 ofert w pierwszym dniu ich istnienia.',
    threshold: 10,
    metric: AchievementMetric.firstDayPurchases,
    shortGoal: '10 szybkich zakupów',
  ),
  AchievementDefinition(
    id: 'quickSale',
    title: 'Pan szybka wyprzedaż',
    description: 'Obniż cenę 20 produktów naraz.',
    threshold: 20,
    metric: AchievementMetric.priceDrops,
    shortGoal: '20 obniżek cen',
  ),
  AchievementDefinition(
    id: 'globetrotter',
    title: 'Obieżyświat',
    description: 'Wystaw 10 ofert, każdą w innym mieście.',
    threshold: 10,
    metric: AchievementMetric.differentCities,
    shortGoal: '10 miast',
  ),
  AchievementDefinition(
    id: 'businessman',
    title: 'Biznesman',
    description: 'Wystaw 500 ofert.',
    threshold: 500,
    metric: AchievementMetric.offersCreated,
    shortGoal: '500 ofert',
  ),
];

int achievementMetricValue(
  AchievementMetric metric,
  ProfileAchievementStats stats,
) {
  return switch (metric) {
    AchievementMetric.offersCreated => stats.offersCreated,
    AchievementMetric.negotiationsCompleted => stats.negotiationsCompleted,
    AchievementMetric.giveOffersCreated => stats.giveOffersCreated,
    AchievementMetric.firstDayPurchases => stats.firstDayPurchases,
    AchievementMetric.priceDrops => stats.priceDrops,
    AchievementMetric.differentCities => stats.differentCities,
  };
}

List<AchievementProgress> buildAchievementProgress(
  ProfileAchievementStats stats,
) {
  return profileAchievementDefinitions
      .map(
        (definition) => AchievementProgress(
          definition: definition,
          current: achievementMetricValue(definition.metric, stats),
        ),
      )
      .toList();
}