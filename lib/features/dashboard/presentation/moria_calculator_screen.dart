import 'package:flutter/material.dart';
import '../../../shared/glass_container.dart';
import '../../../theme/app_theme.dart';
import '../utils/grade_calculator.dart';

class MoriaCalculatorScreen extends StatefulWidget {
  const MoriaCalculatorScreen({super.key});

  @override
  State<MoriaCalculatorScreen> createState() => _MoriaCalculatorScreenState();
}

class _MoriaCalculatorScreenState extends State<MoriaCalculatorScreen> {
  final List<String> orientations = [
    'Ανθρωπιστική',
    'Θετική',
    'Υγεία',
    'Οικονομία',
  ];
  String selectedOrientation = 'Ανθρωπιστική';

  // 4 subjects
  List<double> grades = [15.0, 15.0, 15.0, 15.0];

  double get totalMoria =>
      MoriaCalculator.calculateTotal(grades, orientation: selectedOrientation);

  @override
  Widget build(BuildContext context) {
    return AppTheme.globalGradient(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.brand.darkText),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Υπολογισμός Μορίων',
            style: TextStyle(
              color: context.brand.darkText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Εκτιμώμενα Μόρια',
                          style: TextStyle(
                            color: context.brand.neutralGrey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          totalMoria.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: context.brand.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedOrientation,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Κατεύθυνση',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: orientations
                        .map(
                          (o) => ChoiceChip(
                            label: Text(o),
                            selected: selectedOrientation == o,
                            onSelected: (val) {
                              if (val) setState(() => selectedOrientation = o);
                            },
                            selectedColor: context.brand.mintSuccess.withValues(
                              alpha: 0.5,
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                            labelStyle: TextStyle(
                              color: selectedOrientation == o
                                  ? context.brand.darkText
                                  : context.brand.neutralGrey,
                              fontWeight: selectedOrientation == o
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Βαθμολογίες (0-20)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(4, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  MoriaCalculator.getSubjectsForOrientation(
                                    selectedOrientation,
                                  )[index],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  grades[index].toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: context.brand.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: grades[index],
                              min: 0,
                              max: 20,
                              divisions: 200,
                              activeColor: context.brand.primaryPurple,
                              inactiveColor: context.brand.neutralGrey
                                  .withValues(alpha: 0.2),
                              onChanged: (val) {
                                setState(() {
                                  grades[index] = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
