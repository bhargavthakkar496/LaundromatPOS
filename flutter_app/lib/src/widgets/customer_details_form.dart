import 'package:flutter/material.dart';

class CustomerDetailsForm extends StatelessWidget {
  const CustomerDetailsForm({
    super.key,
    required this.nameController,
    required this.phoneController,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter customer name';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) {
      return 'Enter phone number';
    }
    if (phone.length < 10) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Customer name'),
          validator: validateName,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'Phone number'),
          keyboardType: TextInputType.phone,
          validator: validatePhone,
        ),
      ],
    );
  }
}
