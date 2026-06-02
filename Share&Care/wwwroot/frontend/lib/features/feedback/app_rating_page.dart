import 'package:flutter/material.dart';

class AppRatingPage extends StatefulWidget {
  const AppRatingPage({super.key});

  @override
  State<AppRatingPage> createState() => _AppRatingPageState();
}

class _AppRatingPageState extends State<AppRatingPage> {
  int _rating = 0;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz liczbe gwiazdek.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dziekujemy!'),
        content: Text('Twoja ocena: $_rating/5'),
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
  }

  Widget _buildStar(int index) {
    final isActive = index <= _rating;
    return IconButton(
      onPressed: () {
        setState(() => _rating = index);
      },
      icon: Icon(
        isActive ? Icons.star : Icons.star_border,
        color: isActive ? Colors.amber : Colors.grey,
        size: 32,
      ),
      tooltip: '$index',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: 
        AppBar(
          title: const Text('Ocena aplikacji'),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Jak oceniasz nasza aplikacje?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2, 3, 4, 5].map(_buildStar).toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Wysylanie...' : 'Wylij'),
            ),
          ],
        ),
      ),
    );
  }
}
