import 'package:flutter/material.dart';

import '../../services/rewards_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  bool _loading = false;
  List<RewardItem> _rewards = const [];
  int? _credits;

  @override
  void initState() {
    super.initState();
    _loadRewards();
    _loadCredits();
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

  Future<void> _loadCredits() async {
    try {
      final auth = await AuthService.getStoredAuthResult();
      final userId = auth?.userId;
      if (userId == null || userId.isEmpty) return;

      final profile = await UserProfileService.fetchProfile(userId);
      if (!mounted) return;
      setState(() => _credits = profile.credits);
    } catch (_) {
      // Brak kredytów nie blokuje listy nagród.
    }
  }

  Future<bool> _confirmRedeem() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: const Text('Czy na pewno chcesz odebrać nagrodę?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nie'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tak'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gratulacje!'),
        content: const Text('To twoja nagroda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(RewardItem reward) async {
    final confirmed = await _confirmRedeem();
    if (!confirmed) return;

    try {
      final result = await RewardsService.redeemReward(reward.id);
      if (!mounted) return;
      setState(() => _credits = result.credits);
      await _showSuccessDialog();
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
      appBar: 
        AppBar(
          title: const Text('Nagrody'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _rewards.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    _credits == null
                        ? 'Twoje shareCoiny: —'
                        : 'Twoje shareCoiny: $_credits',
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                }

                final reward = _rewards[index - 1];
                final canRedeem = _credits != null && _credits! >= reward.cost;
                return Card(
                  child: ListTile(
                    title: Text(reward.name),
                    subtitle: Text(reward.description),
                    trailing: ElevatedButton(
                      onPressed: canRedeem ? () => _redeem(reward) : null,
                      child: Text('${reward.cost} shareCoins'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}