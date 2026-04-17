import 'package:flutter/foundation.dart';

import 'machine_integration_demo_service.dart';
import 'machine_integration_service.dart';
import 'machine_integration_sunmi_service.dart';

MachineIntegrationService createDefaultMachineIntegrationService() {
  if (kIsWeb) {
    return DemoMachineIntegrationService();
  }

  return SunmiMachineIntegrationService(
    fallback: DemoMachineIntegrationService(),
  );
}
