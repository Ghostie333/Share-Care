import 'package:flutter/material.dart';

import '../../services/user_profile_service.dart';

class PaymentSurveyPage extends StatefulWidget {
  final String targetUserId;
  final String announcementTitle;

  const PaymentSurveyPage({
    super.key,
    required this.targetUserId,
    required this.announcementTitle,
  });

  @override
  State<PaymentSurveyPage> createState() => _PaymentSurveyPageState();
}

class _PaymentSurveyPageState extends State<PaymentSurveyPage> {
  final List<String> _questions = const [
    'Jak przebiegła rozmowa?',
    'Adekwatność kaucji do jakości?',
    'Jak oceniasz stan w rzeczywistości?'
  ];

  late List<int> _scores;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _scores = List<int>.filled(_questions.length, 3);
  }

  double get _average {
    if (_scores.isEmpty) return 0;
    final total = _scores.fold<int>(0, (sum, value) => sum + value);
    return total / _scores.length;
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final rounded = _average.round();
      await UserProfileService.submitRating(
        userId: widget.targetUserId,
        score: rounded,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dziękujemy!'),
          content: Text(
            'Średnia ocena: ${_average.toStringAsFixed(2)}\n\n'
            'Twoja opinia została zapisana.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać oceny: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocena darczyńcy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Poświęć chwilę aby ocenić darczyńcę',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.announcementTitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _questions.length; i++)
            _buildQuestionCard(i),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            child: ListTile(
              title: const Text('Średnia ocena'),
              trailing: Text(_average.toStringAsFixed(2)),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'Wysyłanie...' : 'Zapisz ocenę'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _questions[index],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('0'),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 5,
                    divisions: 5,
                    value: _scores[index].toDouble(),
                    label: _scores[index].toString(),
                    onChanged: (value) {
                      setState(() {
                        _scores[index] = value.round();
                      });
                    },
                  ),
                ),
                const Text('5'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
