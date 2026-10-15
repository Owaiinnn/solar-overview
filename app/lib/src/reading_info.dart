import 'package:flutter/material.dart';

class ReadingInfoButton extends StatelessWidget {
  const ReadingInfoButton({
    super.key,
    required this.title,
    required this.information,
  });

  final String title;
  final String information;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'About $title',
    icon: const Icon(Icons.info_outline_rounded),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(information)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

class ReadingCardHeader extends StatelessWidget {
  const ReadingCardHeader({super.key, required this.title, this.information});

  final String title;
  final String? information;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (information != null)
        ReadingInfoButton(title: title, information: information!),
    ],
  );
}
