import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/models/gift.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/form_widgets.dart';

class GiftForm extends StatefulWidget {
  final Gift? gift;
  const GiftForm({super.key, this.gift});

  @override
  State<GiftForm> createState() => _GiftFormState();
}

class _GiftFormState extends State<GiftForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.gift != null) {
      _nameController.text = widget.gift!.name;
      _notesController.text = widget.gift!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };
      if (widget.gift?.id != null) {
        await _dbHelper.update('gifts', data,
            where: 'id = ?', whereArgs: [widget.gift!.id]);
      } else {
        await _dbHelper.insert('gifts', data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.gift != null;
    return Scaffold(
      appBar: CustomAppBar(title: isEdit ? 'تعديل الهدية' : 'إضافة هدية'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormSection(
                  title: 'بيانات الهدية',
                  icon: Icons.card_giftcard_rounded,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم الهدية *',
                        prefixIcon: Icon(Icons.card_giftcard),
                      ),
                      textDirection: TextDirection.rtl,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم الهدية' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      textDirection: TextDirection.rtl,
                      maxLines: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _save,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(isEdit ? 'حفظ التعديلات' : 'إضافة الهدية'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

