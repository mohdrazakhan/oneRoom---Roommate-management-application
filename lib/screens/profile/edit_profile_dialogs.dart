// lib/screens/profile/edit_profile_dialogs.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../Models/user_profile.dart';

void showEditNameDialog(BuildContext context, UserProfile profile) {
  final controller = TextEditingController(text: profile.displayName ?? '');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Display Name'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Display Name',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final name = controller.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name cannot be empty')),
              );
              return;
            }

            try {
              await context.read<AuthProvider>().updateProfile({
                'displayName': name,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Name updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showEditTaglineDialog(BuildContext context, UserProfile profile) {
  final controller = TextEditingController(text: profile.tagline ?? '');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Tagline'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Tagline',
          hintText: 'e.g., "Loves cooking and cleaning"',
          border: OutlineInputBorder(),
        ),
        maxLength: 100,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final tagline = controller.text.trim();

            try {
              await context.read<AuthProvider>().updateProfile({
                'tagline': tagline.isEmpty ? null : tagline,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tagline updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showEditPhoneDialog(BuildContext context, UserProfile profile) {
  final controller = TextEditingController(text: profile.phoneNumber ?? '');

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Phone Number'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: 'Phone Number',
          hintText: '+1 234 567 8900',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        keyboardType: TextInputType.phone,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final phone = controller.text.trim();

            try {
              await context.read<AuthProvider>().updateProfile({
                'phoneNumber': phone.isEmpty ? null : phone,
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Phone number updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showEditDOBDialog(BuildContext context, UserProfile profile) async {
  final initialDate = profile.dateOfBirth ?? DateTime(2000);

  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(1900),
    lastDate: DateTime.now(),
    helpText: 'Select Date of Birth',
  );

  if (picked != null && context.mounted) {
    try {
      await context.read<AuthProvider>().updateProfile({'dateOfBirth': picked});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Date of birth updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
