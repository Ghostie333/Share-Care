import 'package:flutter/material.dart';

import '../../services/rewards_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  bool _loading = false;
  List<RewardItem> _rewards = const [];

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() => _loading = true);
    try {
      final rewards = await RewardsService.fetchRewards();
      if (!mounted) return;
      setState(() => _rewards = rewards);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać nagród: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _redeem(RewardItem reward) async {
    try {
      final credits = await RewardsService.redeemReward(reward.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zrealizowano nagrodę. Pozostałe shareCoiny: $credits')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zrealizować: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nagrody')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rewards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final reward = _rewards[index];
                return Card(
                  child: ListTile(
                    title: Text(reward.name),
                    subtitle: Text(reward.description),
                    trailing: ElevatedButton(
                      onPressed: () => _redeem(reward),
                      child: Text('${reward.cost} shareCoins'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
