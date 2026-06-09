import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../features/auth/data/auth_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';
import '../domain/quiz_question.dart';
import '../providers/exam_readiness_providers.dart';
import 'quiz_taking_screen.dart';

class QuizSetupScreen extends ConsumerStatefulWidget {
  const QuizSetupScreen({
    super.key,
    required this.subjectName,
    this.examReference = '',
  });

  final String subjectName;
  final String examReference;

  @override
  ConsumerState<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends ConsumerState<QuizSetupScreen> {
  final Set<QuizQuestionType> _selectedTypes = {
    QuizQuestionType.multipleChoice,
    QuizQuestionType.trueFalse,
  };
  String _difficulty = 'medium';
  int _count = 10;
  final TextEditingController _syllabusController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _scannedImages = <File>[];

  @override
  void dispose() {
    _syllabusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examGenerationProvider);
    final lang = ref.watch(userLanguageProvider);
    final s = S(lang);
    final isGreek = lang == 'el';

    return AppTheme.globalGradient(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(isGreek ? 'Ρύθμιση τεστ ExamIQ' : 'ExamIQ Test Setup'),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${s.subject}: ${widget.subjectName}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              isGreek ? 'Θέμα τεστ' : 'Test subject',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InputChip(
                  label: Text(widget.subjectName),
                  selected: true,
                  onPressed: null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isGreek
                  ? 'Το μάθημα ορίζεται από το κουμπί "Κάνε τεστ" στη λίστα εξετάσεων.'
                  : 'The subject is selected from the "Take test" button next to each exam.',
              style: TextStyle(color: context.brand.neutralGrey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              isGreek
                  ? 'Ύλη / Κεφάλαια (χειροκίνητα)'
                  : 'Syllabus / Chapters (manual)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _syllabusController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: isGreek
                    ? 'Γράψε ή κάνε επικόλληση της ύλης (π.χ. Κεφάλαιο 3, ασκήσεις 1-20...)'
                    : 'Write or paste syllabus (e.g. Chapter 3, exercises 1-20...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isGreek
                  ? 'Σάρωση σελίδων βιβλίου/σημειώσεων'
                  : 'Scan book/notes pages',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      isGreek ? 'Επιλογή από συλλογή' : 'Pick from gallery',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(isGreek ? 'Λήψη φωτογραφίας' : 'Take photo'),
                  ),
                ),
              ],
            ),
            if (_scannedImages.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _scannedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final file = _scannedImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            file,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _scannedImages.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              isGreek ? 'Τύποι ερωτήσεων' : 'Question types',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _typeTile(
              isGreek ? 'Πολλαπλής επιλογής' : 'Multiple choice',
              QuizQuestionType.multipleChoice,
            ),
            _typeTile(
              isGreek ? 'Σωστό / Λάθος' : 'True / False',
              QuizQuestionType.trueFalse,
            ),
            _typeTile(
              isGreek ? 'Συμπλήρωσης κενού' : 'Fill in the blank',
              QuizQuestionType.fillBlank,
            ),
            _typeTile(
              isGreek ? 'Ανάπτυξης' : 'Open-ended',
              QuizQuestionType.development,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _difficulty,
              decoration: InputDecoration(
                labelText: isGreek ? 'Δυσκολία' : 'Difficulty',
              ),
              items: [
                DropdownMenuItem(
                  value: 'easy',
                  child: Text(isGreek ? 'Εύκολο' : 'Easy'),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: Text(isGreek ? 'Μεσαίο' : 'Medium'),
                ),
                DropdownMenuItem(
                  value: 'hard',
                  child: Text(isGreek ? 'Δύσκολο' : 'Hard'),
                ),
              ],
              onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
            ),
            const SizedBox(height: 12),
            Text(
              isGreek
                  ? 'Αριθμός ερωτήσεων: $_count'
                  : 'Number of questions: $_count',
            ),
            Slider(
              min: 5,
              max: 20,
              divisions: 3,
              value: _count.toDouble(),
              onChanged: (v) => setState(() => _count = v.round()),
            ),
            const SizedBox(height: 20),
            Text(
              isGreek
                  ? 'Κόστος: 2 Sparks για δημιουργία τεστ (+1 Spark αν περιέχει ερωτήσεις ανάπτυξης/κενού για AI διόρθωση).'
                  : 'Cost: 2 Sparks to generate a test (+1 Spark if open questions require AI grading).',
              style: TextStyle(color: context.brand.neutralGrey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: state.isLoading ? null : _onGenerate,
              child: state.isLoading
                  ? const CircularProgressIndicator()
                  : Text(isGreek ? 'Δημιουργία τεστ' : 'Generate test'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(color: context.brand.errorRed),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeTile(String label, QuizQuestionType type) {
    return CheckboxListTile(
      value: _selectedTypes.contains(type),
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      onChanged: (v) {
        setState(() {
          if (v == true) {
            _selectedTypes.add(type);
          } else {
            _selectedTypes.remove(type);
          }
        });
      },
    );
  }

  Future<void> _onGenerate() async {
    if (_selectedTypes.isEmpty) {
      final isGreek = ref.read(userLanguageProvider) == 'el';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isGreek
                ? 'Επίλεξε τουλάχιστον έναν τύπο ερώτησης.'
                : 'Select at least one question type.',
          ),
        ),
      );
      return;
    }
    final quiz = await ref
        .read(examGenerationProvider.notifier)
        .generateQuiz(
          subjectName: widget.subjectName,
          topics: <String>[widget.subjectName],
          questionTypes: _selectedTypes.toList(),
          count: _count,
          difficulty: _difficulty,
          language: ref.read(userLanguageProvider),
          syllabusText: _syllabusController.text.trim(),
          scannedImages: _scannedImages,
        );
    if (!mounted || quiz == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizTakingScreen(
          quiz: quiz,
          subjectName: widget.subjectName,
          subjectId: widget.subjectName.toLowerCase().replaceAll(' ', '_'),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 70);
    if (files.isEmpty) return;
    setState(() {
      _scannedImages.addAll(files.map((x) => File(x.path)));
    });
  }

  Future<void> _pickFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (file == null) return;
    setState(() {
      _scannedImages.add(File(file.path));
    });
  }
}
