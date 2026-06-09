enum QuizQuestionType { multipleChoice, trueFalse, fillBlank, development }

QuizQuestionType quizQuestionTypeFromString(String raw) {
  switch (raw.trim()) {
    case 'multipleChoice':
      return QuizQuestionType.multipleChoice;
    case 'trueFalse':
      return QuizQuestionType.trueFalse;
    case 'fillBlank':
      return QuizQuestionType.fillBlank;
    case 'development':
      return QuizQuestionType.development;
    default:
      return QuizQuestionType.multipleChoice;
  }
}

String quizQuestionTypeToString(QuizQuestionType type) {
  switch (type) {
    case QuizQuestionType.multipleChoice:
      return 'multipleChoice';
    case QuizQuestionType.trueFalse:
      return 'trueFalse';
    case QuizQuestionType.fillBlank:
      return 'fillBlank';
    case QuizQuestionType.development:
      return 'development';
  }
}

class QuizQuestion {
  final String questionText;
  final QuizQuestionType type;
  final List<String> options;
  final String correctAnswer;
  final String topicTag;
  final String explanation;

  const QuizQuestion({
    required this.questionText,
    required this.type,
    this.options = const [],
    required this.correctAnswer,
    required this.topicTag,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionText': questionText,
      'type': quizQuestionTypeToString(type),
      'options': options,
      'correctAnswer': correctAnswer,
      'topicTag': topicTag,
      'explanation': explanation,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      questionText: (map['questionText'] ?? '').toString(),
      type: quizQuestionTypeFromString((map['type'] ?? '').toString()),
      options: List<String>.from(map['options'] ?? const <String>[]),
      correctAnswer: (map['correctAnswer'] ?? '').toString(),
      topicTag: (map['topicTag'] ?? '').toString(),
      explanation: (map['explanation'] ?? '').toString(),
    );
  }
}
