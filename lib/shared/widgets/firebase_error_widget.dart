import 'package:flutter/material.dart';

class FirebaseErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const FirebaseErrorWidget({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final errorString = error.toString();
    final isIndexError = errorString.contains('requires an index');
    final isPermissionError = errorString.contains('permission-denied');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              isIndexError
                  ? 'Missing Database Index'
                  : isPermissionError
                  ? 'Access Denied'
                  : 'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isIndexError
                  ? 'Your Firestore database needs a composite index to show this list. Please check the terminal or console for the link to create it.'
                  : isPermissionError
                  ? 'You don\'t have permission to access this data. Please check your Firestore Security Rules.'
                  : errorString,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (onRetry != null && !isIndexError && !isPermissionError)
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
