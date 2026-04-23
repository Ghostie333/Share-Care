import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class HistoryPage extends StatelessWidget {
  final AuthResult authResult;

  const HistoryPage({super.key, required this.authResult});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Historia'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HistoryCategoryTile(
            title: 'Historia wyszukiwania',
            subtitle: 'Ostatnie wyszukiwania (w przygotowaniu)',
            icon: Icons.search,
          ),
          SizedBox(height: 12),
          _HistoryCategoryTile(
            title: 'Historia ogłoszeń',
            subtitle: 'Twoje utworzone/edytowane ogłoszenia (w przygotowaniu)',
            icon: Icons.campaign_outlined,
          ),
          SizedBox(height: 12),
          _HistoryCategoryTile(
            title: 'Historia czatów',
            subtitle: 'Ostatnie rozmowy/archiwum (w przygotowaniu)',
            icon: Icons.chat_bubble_outline,
          ),
          SizedBox(height: 12),
          _HistoryCategoryTile(
            title: 'Inne',
            subtitle: 'Dodatkowe historie (w przygotowaniu)',
            icon: Icons.history,
          ),
        ],
      ),
    );
  }
}

class _HistoryCategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HistoryCategoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ta sekcja jest w przygotowaniu.')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
