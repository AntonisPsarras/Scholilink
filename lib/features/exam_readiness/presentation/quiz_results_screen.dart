import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../domain/exam_quiz.dart';
import '../domain/quiz_attempt.dart';

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({
    super.key,
    required this.quiz,
    required this.attempt,
  });

  final ExamQuiz quiz;
  final QuizAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final isGreek = Localizations.localeOf(context).languageCode == 'el';
    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(isGreek ? 'Αποτελέσματα τεστ' : 'Test Results'),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${isGreek ? 'Συνολικό σκορ' : 'Total score'}: ${attempt.score.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              isGreek ? 'Ανάλυση ανά θέμα' : 'Topic breakdown',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...attempt.topicBreakdown.entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Text('${e.value.toStringAsFixed(0)}%'),
              ),
            ),
            const Divider(),
            Text(
              isGreek ? 'Επεξηγήσεις' : 'Explanations',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...quiz.generatedQuestions.map(
              (q) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(q.questionText),
                subtitle: Text(
                  q.explanation.isEmpty
                      ? (isGreek
                            ? 'Χωρίς επιπλέον εξήγηση.'
                            : 'No additional explanation.')
                      : q.explanation,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
