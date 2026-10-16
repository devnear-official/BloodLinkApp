import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/blood_request_model.dart';
import '../../providers/request_provider.dart';
import '../auth/register_screen.dart' show kBloodGroups;
import '../shared/location_selector.dart';

const List<String> kPriorities = ['Low', 'Medium', 'High', 'Critical'];

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();

  String _bloodGroup = kBloodGroups.first;
  String _priority = 'Medium';
  String? _division;
  String? _district;
  String? _subDistrict;
  DateTime? _requiredDate;
  bool _submitting = false;

  @override
  void dispose() {
    _patientNameController.dispose();
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
    if (picked != null) setState(() => _requiredDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_division == null || _district == null || _subDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a division, district, and sub-district'),
        ),
      );
      return;
    }
    if (_requiredDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a required date')),
      );
      return;
    }

    setState(() => _submitting = true);

    final request = BloodRequestModel(
      id: '',
      patientName: _patientNameController.text.trim(),
      bloodGroup: _bloodGroup,
      hospitalName: _hospitalController.text.trim(),
      contactNumber: _contactController.text.trim(),
      division: _division!,
      district: _district!,
      subDistrict: _subDistrict,
      requiredDate: _requiredDate,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
      priority: _priority,
    );

    final success =
        await context.read<RequestProvider>().createRequest(request);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood request posted'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = context.read<RequestProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to create request'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('New Blood Request')),
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 620,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _patientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Patient Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _bloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood Group Needed',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                    ),
                    items: kBloodGroups
                        .map((bg) =>
                            DropdownMenuItem(value: bg, child: Text(bg)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _bloodGroup = value ?? _bloodGroup),
                  ),
                  const SizedBox(height: 16),
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
                  LocationSelector(
                    division: _division,
                    district: _district,
                    subDistrict: _subDistrict,
                    showSubDistrict: true,
                    onDivisionChanged: (value) => setState(() {
                      _division = value;
                      _district = null;
                      _subDistrict = null;
                    }),
                    onDistrictChanged: (value) => setState(() {
                      _district = value;
                      _subDistrict = null;
                    }),
                    onSubDistrictChanged: (value) =>
                        setState(() => _subDistrict = value),
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
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      prefixIcon: Icon(Icons.priority_high),
                    ),
                    items: kPriorities
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _priority = value ?? _priority),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Additional Message (optional)',
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
                        : const Text('Post Request'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
