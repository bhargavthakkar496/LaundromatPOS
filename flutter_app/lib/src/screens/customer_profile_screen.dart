import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pos_repository.dart';
import '../localization/app_localizations.dart';
import '../models/customer_profile.dart';
import '../widgets/customer_details_form.dart';
import '../widgets/machine_icon.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key, required this.repository});

  final PosRepository repository;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _lookupFormKey = GlobalKey<FormState>();
  final _onboardingFormKey = GlobalKey<FormState>();
  final _lookupPhoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _washerSizeController = TextEditingController();
  final _detergentController = TextEditingController();
  final _dryerDurationController = TextEditingController();
  Future<CustomerProfile?>? _profileFuture;
  bool _savingCustomer = false;

  @override
  void dispose() {
    _lookupPhoneController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _washerSizeController.dispose();
    _detergentController.dispose();
    _dryerDurationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final phoneError = CustomerDetailsForm.validatePhone(
      _lookupPhoneController.text,
    );
    if (phoneError != null) {
      _lookupFormKey.currentState?.validate();
      return;
    }

    setState(() {
      _profileFuture = widget.repository.getCustomerProfileByPhone(
        _lookupPhoneController.text.trim(),
      );
    });
  }

  Future<void> _saveCustomer() async {
    if (!_onboardingFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _savingCustomer = true;
    });

    final customer = await widget.repository.saveWalkInCustomer(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      preferredWasherSizeKg: int.tryParse(_washerSizeController.text.trim()),
      preferredDetergentAddOn: _detergentController.text.trim().isEmpty
          ? null
          : _detergentController.text.trim(),
      preferredDryerDurationMinutes: int.tryParse(
        _dryerDurationController.text.trim(),
      ),
    );

    if (!mounted) {
      return;
    }

    _lookupPhoneController.text = customer.phone;
    setState(() {
      _savingCustomer = false;
      _profileFuture =
          widget.repository.getCustomerProfileByPhone(customer.phone);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${customer.fullName} is ready for lookup and checkout.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.customerLookup)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Search a previous customer by phone number, or onboard a new customer from the same manager screen.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _lookupFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous Customer Search',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lookupPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Customer phone number',
                            ),
                            validator: CustomerDetailsForm.validatePhone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _loadProfile,
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _onboardingFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Customer Onboarding',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture a new customer here so the profile is reusable for checkout, reservations, and future visits.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    CustomerDetailsForm(
                      nameController: _nameController,
                      phoneController: _phoneController,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _washerSizeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Preferred washer size (kg)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _dryerDurationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Preferred dryer time (min)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _detergentController,
                      decoration: const InputDecoration(
                        labelText: 'Preferred detergent add-on',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _savingCustomer ? null : _saveCustomer,
                      child: Text(
                        _savingCustomer ? 'Saving...' : 'Onboard Customer',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_profileFuture != null)
            FutureBuilder<CustomerProfile?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final profile = snapshot.data;
                if (profile == null) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No repeat-customer profile was found for that phone number yet.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  );
                }

                return _CustomerProfileView(profile: profile);
              },
            ),
        ],
      ),
    );
  }
}

class _CustomerProfileView extends StatelessWidget {
  const _CustomerProfileView({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.customer.fullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(profile.customer.phone),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'Visits',
                        value: '${profile.totalVisits}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        label: 'Spent',
                        value: 'INR ${profile.totalSpent.toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Saved Preferences',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.customer.preferredWasherSizeKg == null
                      ? 'Preferred washer size: Not set'
                      : 'Preferred washer size: ${profile.customer.preferredWasherSizeKg}kg',
                ),
                const SizedBox(height: 8),
                Text(
                  'Detergent add-on: ${profile.customer.preferredDetergentAddOn ?? 'Not set'}',
                ),
                const SizedBox(height: 8),
                Text(
                  profile.customer.preferredDryerDurationMinutes == null
                      ? 'Preferred dryer duration: Not set'
                      : 'Preferred dryer duration: ${profile.customer.preferredDryerDurationMinutes} min',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Upcoming Reservations',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (profile.upcomingReservations.isEmpty)
          const Text('No upcoming reservations yet.')
        else
          ...profile.upcomingReservations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: MachineIcon(machine: item.machine),
                  title: Text(item.machine.name),
                  subtitle: Text(
                    '${dateFormat.format(item.reservation.startTime)} - ${DateFormat('hh:mm a').format(item.reservation.endTime)}',
                  ),
                  trailing: Text(item.reservation.status),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Favorite Machines',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (profile.favoriteMachines.isEmpty)
          const Text('No machine preferences yet.')
        else
          ...profile.favoriteMachines.map(
            (favorite) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: MachineIcon(machine: favorite.machine),
                  title: Text(favorite.machine.name),
                  subtitle: Text(
                    '${favorite.machine.type} • ${favorite.machine.capacityKg}kg',
                  ),
                  trailing: Text('${favorite.usageCount} uses'),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Past Orders',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...profile.orders.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                leading: MachineIcon(machine: item.machine),
                title: Text(
                  '${item.machine.name} • INR ${item.order.amount.toStringAsFixed(0)}',
                ),
                subtitle: Text(
                  '${item.order.paymentMethod} • ${dateFormat.format(item.order.timestamp)}',
                ),
                trailing: Text(item.order.paymentStatus),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
