import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
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
  bool _uploadingPhoto = false;
  final _imagePicker = ImagePicker();

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

  Future<void> _changeProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final photo = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (photo == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final user = await context.read<UserProvider>().uploadProfilePhoto(photo);
      if (!mounted) return;
      if (user == null) {
        final message =
            context.read<UserProvider>().errorMessage ?? 'Photo upload failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
        return;
      }
      await context.read<AuthProvider>().updateCachedUser(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update profile photo: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
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
    final user = context.watch<AuthProvider>().currentUser!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Edit Profile')),
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
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: colors.primaryContainer,
                          backgroundImage: user.photoUrl == null
                              ? null
                              : NetworkImage(user.photoUrl!),
                          child: user.photoUrl == null
                              ? Text(
                                  user.name.isEmpty
                                      ? '?'
                                      : user.name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: colors.onPrimaryContainer,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: IconButton.filled(
                            tooltip: 'Change profile photo',
                            onPressed:
                                _uploadingPhoto ? null : _changeProfilePhoto,
                            icon: _uploadingPhoto
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_outlined,
                                    size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    initialValue: _bloodGroup,
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                    ),
                    items: kBloodGroups
                        .map((bg) =>
                            DropdownMenuItem(value: bg, child: Text(bg)))
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
                    activeThumbColor: AppColors.primary,
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
      ),
    );
  }
}
