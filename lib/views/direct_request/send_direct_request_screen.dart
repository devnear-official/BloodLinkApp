import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/direct_request_model.dart';
import '../../models/user_model.dart';
import '../../providers/direct_request_provider.dart';

/// Lets the current user send a direct donation request to a specific
/// [donor] found via donor search.
class SendDirectRequestScreen extends StatefulWidget {
  const SendDirectRequestScreen({super.key, required this.donor});

  final UserModel donor;

  @override
  State<SendDirectRequestScreen> createState() =>
      _SendDirectRequestScreenState();
}

class _SendDirectRequestScreenState extends State<SendDirectRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();
  DateTime? _requiredDate;
  bool _submitting = false;

  @override
  void dispose() {
    _hospitalController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _requiredDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final request = DirectRequestModel(
      id: '',
      fromUser: widget.donor, // placeholder; server sets the real fromUser
      toUser: widget.donor,
      bloodGroup: widget.donor.bloodGroup ?? '',
      hospitalName: _hospitalController.text.trim(),
      contactNumber: _contactController.text.trim(),
      requiredDate: _requiredDate,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    );

    final success = await context.read<DirectRequestProvider>().sendDirectRequest(
          request,
          toUserId: widget.donor.id,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to ${widget.donor.name}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = context.read<DirectRequestProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to send request'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Request ${widget.donor.name}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: AppColors.primaryLight,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            widget.donor.bloodGroup ?? '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.donor.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${widget.donor.district ?? "—"}, ${widget.donor.division ?? "—"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _hospitalController,
                  decoration: const InputDecoration(
                    labelText: 'Hospital Name',
                    prefixIcon: Icon(Icons.local_hospital_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Required Date',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      _requiredDate == null
                          ? 'Select a date'
                          : '${_requiredDate!.year}-${_requiredDate!.month.toString().padLeft(2, '0')}-${_requiredDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
