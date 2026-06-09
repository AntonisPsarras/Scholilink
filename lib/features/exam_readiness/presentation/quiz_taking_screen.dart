import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/exam_quiz.dart';
import '../domain/quiz_question.dart';
import '../providers/exam_readiness_providers.dart';
import 'quiz_results_screen.dart';

class QuizTakingScreen extends ConsumerStatefulWidget {
  const QuizTakingScreen({
    super.key,
    required this.quiz,
    required this.subjectId,
    required this.subjectName,
  });

  final ExamQuiz quiz;
  final String subjectId;
  final String subjectName;

  @override
  ConsumerState<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends ConsumerState<QuizTakingScreen> {
  final Map<int, String> _answers = {};
  int _index = 0;
  int _instantCorrect = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examGenerationProvider);
    final lang = ref.watch(userLanguageProvider);
    final isGreek = lang == 'el';
    final q = widget.quiz.generatedQuestions[_index];

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '${isGreek ? 'Ερώτηση' : 'Question'} ${_index + 1}/${widget.quiz.generatedQuestions.length}',
          ),
          backgroundColor: Colors.transparent,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.topicTag,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(q.questionText, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              Expanded(child: _questionInput(q)),
              if (q.type == QuizQuestionType.multipleChoice ||
                  q.type == QuizQuestionType.trueFalse)
                Text(
                  isGreek
                      ? 'Άμεσο σκορ: $_instantCorrect'
                      : 'Instant score: $_instantCorrect',
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_index > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _index--),
                      child: Text(isGreek ? 'Πίσω' : 'Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: state.isLoading
                        ? null
                        : (_index == widget.quiz.generatedQuestions.length - 1
                              ? _submit
                              : () => setState(() => _index++)),
                    child: Text(
                      _index == widget.quiz.generatedQuestions.length - 1
                          ? (isGreek ? 'Ολοκλήρωση' : 'Finish')
                          : (isGreek ? 'Επόμενη' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionInput(QuizQuestion q) {
    final lang = ref.watch(userLanguageProvider);
    final isGreek = lang == 'el';
    switch (q.type) {
      case QuizQuestionType.multipleChoice:
        return Column(
          children: q.options
              .map(
                (opt) => ListTile(
                  leading: Icon(
                    _answers[_index] == opt
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(opt),
                  onTap: () {
                    final wasCorrect = _answers[_index] == q.correctAnswer;
                    final nowCorrect = opt == q.correctAnswer;
                    setState(() {
                      _answers[_index] = opt;
                      if (!wasCorrect && nowCorrect) _instantCorrect++;
                      if (wasCorrect && !nowCorrect) _instantCorrect--;
                    });
                  },
                ),
              )
              .toList(),
        );
      case QuizQuestionType.trueFalse:
        final trueLabel = isGreek ? 'Σωστό' : 'True';
        final falseLabel = isGreek ? 'Λάθος' : 'False';
        return Column(
          children: [trueLabel, falseLabel]
              .map(
                (opt) => ListTile(
                  leading: Icon(
                    _answers[_index] == opt
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(opt),
                  onTap: () {
                    final wasCorrect = _answers[_index] == q.correctAnswer;
                    final nowCorrect = opt == q.correctAnswer;
                    setState(() {
                      _answers[_index] = opt;
                      if (!wasCorrect && nowCorrect) _instantCorrect++;
                      if (wasCorrect && !nowCorrect) _instantCorrect--;
                    });
                  },
                ),
              )
              .toList(),
        );
      case QuizQuestionType.fillBlank:
      case QuizQuestionType.development:
        return TextFormField(
          key: ValueKey('answer_$_index'),
          initialValue: _answers[_index] ?? '',
          maxLines: q.type == QuizQuestionType.development ? 6 : 2,
          decoration: InputDecoration(
            hintText: isGreek
                ? 'Γράψε την απάντησή σου...'
                : 'Write your answer...',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _answers[_index] = v,
        );
    }
  }

  Future<void> _submit() async {
    final attempt = await ref
        .read(examGenerationProvider.notifier)
        .submitAttempt(
          quiz: widget.quiz,
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
          answersByIndex: _answers,
          language: ref.read(userLanguageProvider),
        );
    if (!mounted) return;
    if (attempt == null) {
      final isGreek = ref.read(userLanguageProvider) == 'el';
      final err = ref.read(examGenerationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err ??
                (isGreek
                    ? 'Αποτυχία ολοκλήρωσης τεστ. Δοκίμασε ξανά.'
                    : 'Could not finish the test. Please try again.'),
          ),
        ),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultsScreen(quiz: widget.quiz, attempt: attempt),
      ),
    );
  }
}
