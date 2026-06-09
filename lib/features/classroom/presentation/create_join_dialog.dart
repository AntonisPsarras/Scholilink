import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/classroom_service.dart';
import '../../../theme/app_theme.dart';
import '../../../shared/l10n.dart';

void showCreateJoinDialog(
  BuildContext context,
  WidgetRef ref,
  String userId,
  String lang, {
  int initialTab = 0,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) =>
        _CreateJoinSheet(userId: userId, lang: lang, initialTab: initialTab),
  );
}

class _CreateJoinSheet extends ConsumerStatefulWidget {
  final String userId;
  final String lang;
  final int initialTab;
  const _CreateJoinSheet({
    required this.userId,
    required this.lang,
    this.initialTab = 0,
  });

  @override
  ConsumerState<_CreateJoinSheet> createState() => _CreateJoinSheetState();
}

class _CreateJoinSheetState extends ConsumerState<_CreateJoinSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.brand.neutralGrey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            TabBar(
              controller: _tabController,
              labelColor: context.brand.royalLavender,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: context.brand.royalLavender,
              tabs: [
                Tab(text: s.createClassroom),
                Tab(text: s.joinClassroom),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Create tab
                  Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: s.classroomName,
                          hintText: s.lang == 'el'
                              ? 'π.χ. Β3 - Λύκειο'
                              : 'e.g. B3 - Lyceum',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? context.brand.inputFill
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descController,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: s.description,
                          hintText: s.lang == 'el'
                              ? 'Προαιρετική περιγραφή...'
                              : 'Optional description...',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? context.brand.inputFill
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _createClassroom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.brand.royalLavender,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(s.createClassroom),
                        ),
                      ),
                    ],
                  ),
                  // Join tab
                  Column(
                    children: [
                      TextField(
                        controller: _codeController,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: s.inviteCode,
                          hintText: '123456',
                          labelStyle: TextStyle(color: cs.onSurfaceVariant),
                          hintStyle: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? context.brand.inputFill
                              : Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: context.brand.errorRed,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _joinClassroom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.brand.royalLavender,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(s.joinClassroom),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createClassroom() async {
    if (_nameController.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(classroomServiceProvider)
          .createClassroom(
            _nameController.text,
            widget.userId,
            description: _descController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _joinClassroom() async {
    if (_codeController.text.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final s = S(widget.lang);
      final result = await ref
          .read(classroomServiceProvider)
          .joinClassroom(_codeController.text, widget.userId);
      if (result == null) {
        setState(() {
          _error = s.invalidCode;
          _loading = false;
        });
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
}
