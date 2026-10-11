import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../auth/register_screen.dart' show kBloodGroups;
import '../shared/location_selector.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String? _bloodGroup;
  String? _division;
  String? _district;
  String? _subDistrict;
  String _status = 'Available';
  DateTime? _lastDonation;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser!;
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phone ?? '');
    _bloodGroup = user.bloodGroup;
    _division = user.division;
    _district = user.district;
    _subDistrict = user.subDistrict;
    _status = user.status;
    _lastDonation = user.lastDonation;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickLastDonationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDonation ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _lastDonation = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final updates = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'bloodGroup': _bloodGroup,
      'division': _division,
      'district': _district,
      'upazila': _subDistrict,
      'status': _status,
      if (_lastDonation != null)
        'lastDonation': _lastDonation!.toIso8601String(),
    };

    final updated = await context.read<UserProvider>().updateProfile(updates);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (updated != null) {
      await context.read<AuthProvider>().updateCachedUser(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final error = context.read<UserProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to update profile'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _bloodGroup,
                  decoration: const InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: Icon(Icons.bloodtype_outlined),
                  ),
                  items: kBloodGroups
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (value) => setState(() => _bloodGroup = value),
                ),
                const SizedBox(height: 16),
                LocationSelector(
                  division: _division,
                  district: _district,
                  subDistrict: _subDistrict,
                  requiredFields: false,
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
                  onTap: _pickLastDonationDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Last Donation Date',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(
                      _lastDonation == null
                          ? 'Never donated'
                          : '${_lastDonation!.year}-${_lastDonation!.month.toString().padLeft(2, '0')}-${_lastDonation!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available to Donate'),
                  subtitle: Text(
                    _status == 'Available'
                        ? 'You will appear in donor search'
                        : "You won't appear in donor search",
                  ),
                  value: _status == 'Available',
                  activeColor: AppColors.primary,
                  onChanged: (value) => setState(
                    () => _status = value ? 'Available' : 'Unavailable',
                  ),
                ),
                const SizedBox(height: 16),
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
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
